use bevy::prelude::*;
use linuxfb::Framebuffer;

#[derive(Resource)]
pub struct FB(pub Framebuffer);
