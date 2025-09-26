use bevy::{
    a11y::AccessibilityPlugin,
    asset::RenderAssetUsages,
    core_pipeline::tonemapping::Tonemapping,
    math::FloatOrd,
    pbr::wireframe::{WireframeConfig, WireframePlugin},
    prelude::*,
    render::{
        camera::{ImageRenderTarget, RenderTarget},
        pipelined_rendering::PipelinedRenderingPlugin,
        render_resource::{Extent3d, TextureDimension, TextureFormat, TextureUsages},
        renderer::RenderDevice,
    },
    winit::WinitPlugin,
};
use crossbeam::channel::{unbounded, Receiver, Sender};
use pyo3::prelude::*;
use std::{
    f32::consts::PI,
    thread::{spawn, JoinHandle},
};

use crate::image_copy::{ImageCopier, ImageCopyPlugin, ImageToSave, SceneController, SceneState};

pub mod image_copy;
pub mod sphere;

fn setup(
    mut commands: Commands,
    mut images: ResMut<Assets<Image>>,
    mut scene_controller: ResMut<SceneController>,
    render_device: Res<RenderDevice>,
) {
    // Create an image asset to render to
    let size = Extent3d {
        width: 1280,
        height: 720,
        depth_or_array_layers: 1,
    };
    let bg = ClearColor::default().0.to_linear();

    let mut image = Image::new_fill(
        size,
        TextureDimension::D2,
        // &[0, 0, 0, 255],
        &[
            (bg.red * 255.).round() as u8,
            (bg.green * 255.).round() as u8,
            (bg.blue * 255.).round() as u8,
            255,
        ],
        TextureFormat::Rgba8UnormSrgb,
        // RenderAssetUsages::RENDER_WORLD | RenderAssetUsages::MAIN_WORLD,
        RenderAssetUsages::default(),
    );
    // You need to set these texture usage flags in order to use the image as a render target
    image.texture_descriptor.usage = TextureUsages::TEXTURE_BINDING
        | TextureUsages::COPY_DST
        | TextureUsages::RENDER_ATTACHMENT
        | TextureUsages::COPY_SRC;

    let render_target_handle = images.add(image);

    commands.spawn((
        Camera3d::default(),
        Transform::from_xyz(0.0, 0.0, 4.0).looking_at(Vec3::new(0.0, 0.0, 0.0), Vec3::Y),
        Camera {
            target: RenderTarget::Image(ImageRenderTarget {
                handle: render_target_handle.clone(),
                scale_factor: FloatOrd(1.0),
            }),
            ..default()
        },
        Projection::Perspective(PerspectiveProjection {
            // far: 1_000.0,
            far: 1_000_000.0,
            ..default()
        }),
        Tonemapping::None,
    ));

    commands.spawn(ImageCopier::new(
        render_target_handle.clone(),
        size,
        &render_device,
    ));

    let intensity = 10_000_000.0;
    let light = PointLight {
        shadows_enabled: true,
        intensity,
        range: 1_000_000.0,
        shadow_depth_bias: 0.2,
        radius: PI * 0.5,
        ..default()
    };

    commands.spawn((
        light,
        Transform::from_xyz(1.0, 1.0, 8.0).looking_at(Vec3::new(0.0, 0.0, 0.0), Vec3::Y),
    ));

    // This is the texture that will be copied to.
    let cpu_image = Image::new_fill(
        size,
        TextureDimension::D2,
        &[0; 4],
        TextureFormat::bevy_default(),
        RenderAssetUsages::default(),
    );
    let cpu_image_handle = images.add(cpu_image);

    commands.spawn(ImageToSave(cpu_image_handle));

    scene_controller.state = SceneState::Render(0);
}

#[pyclass]
pub struct IPC {
    _thread_jh: JoinHandle<()>,
    send: Sender<()>,
    recv: Receiver<Vec<u8>>,
}

#[pymethods]
impl IPC {
    fn recv(&self) -> Option<Vec<u8>> {
        // send a signal to bevy thread with a one shot receiver that
        // debug!("asking for new frame");

        self.recv.try_iter().last()
    }

    fn stop(&self) {
        if let Err(e) = self.send.send(()) {
            error!("failed to stop bevy {e}")
        }
    }
}

#[pyfunction]
fn run() -> IPC {
    let to_bevy = unbounded();
    let from_bevy = unbounded();

    let runner = move |mut app: App| {
        app.finish();

        loop {
            app.update();

            if let Some(exit) = app.should_exit() {
                return exit;
            }

            if to_bevy.1.try_recv().is_ok() {
                return AppExit::Success;
            }
        }
    };

    IPC {
        send: to_bevy.0,
        recv: from_bevy.1,
        _thread_jh: spawn(move || {
            App::new()
                .insert_resource(SceneController::new(1280, 720, false))
                .add_plugins((
                    DefaultPlugins
                        .set(ImagePlugin::default_nearest())
                        .disable::<WinitPlugin>()
                        .disable::<PipelinedRenderingPlugin>()
                        .disable::<AccessibilityPlugin>(),
                    WireframePlugin::default(),
                    sphere::SphereMode,
                ))
                .add_plugins(ImageCopyPlugin {
                    sender: from_bevy.0,
                })
                .insert_resource(WireframeConfig {
                    // The global wireframe config enables drawing of wireframes on every mesh,
                    // except those with `NoWireframe`. Meshes with `Wireframe` will always have a wireframe,
                    // regardless of the global configuration.
                    global: true,
                    // Controls the default color of all wireframes. Used as the default color for global wireframes.
                    // Can be changed per mesh using the `WireframeColor` component.
                    default_color: Srgba {
                        red: (166. / 255.),
                        green: (227. / 255.),
                        blue: (161. / 255.),
                        alpha: 1.0,
                    }
                    .into(),
                })
                .insert_resource(ClearColor(
                    Srgba {
                        red: (30. / 255.),
                        green: (30. / 255.),
                        blue: (46. / 255.),
                        alpha: 0.25,
                    }
                    .into(),
                ))
                .init_resource::<SceneController>()
                .add_systems(Startup, setup)
                .set_runner(runner)
                .run();
        }),
    }
}

/// A Python module implemented in Rust.
#[pymodule]
fn bevy_pyo3_test(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<IPC>()?;

    m.add_function(wrap_pyfunction!(run, m)?)?;
    Ok(())
}
