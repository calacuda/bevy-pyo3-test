import pygame
import bevy_pyo3_test


def pygame_main(receiver_conn):
    pygame.init()
    width, height = 1280, 720
    screen = pygame.display.set_mode((width, height))
    pygame.display.set_caption("Bevy Rendered to Pygame")
    font = pygame.font.SysFont("Arial", 24)
    clock = pygame.time.Clock()
    fps_text = "FPS = ?"

    running = True

    while running:
        current_fps = clock.get_fps()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

        encoded_image_data = receiver_conn.recv()

        if encoded_image_data is not None:
            image_data = encoded_image_data

            # Create a Pygame surface from the received image data
            image_surface = pygame.image.frombuffer(
                image_data, (width, height), "RGBA"
            )
            image_surface.set_alpha(None)
            fps_text = font.render(
                # Render in white
                f"FPS: {int(current_fps)}", True, (254, 255, 255))
            screen.blit(image_surface, (0, 0))
            screen.blit(fps_text, (10, 10))  # Position the text at (10, 10)

        pygame.display.flip()
        clock.tick()

    receiver_conn.stop()
    pygame.quit()


def run():
    # start bevy thread
    ipc = bevy_pyo3_test.run()

    # run pygame
    pygame_main(ipc)


if __name__ == "__main__":
    run()
