import socket
import serial

UDP_IP = "127.0.0.1"
UDP_PORT = 5005

try:
    with serial.Serial("COM4", 115200, timeout=1) as controller:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
            print(f"Connected to COM4. Sending UDP to {UDP_IP}:{UDP_PORT}")

            while True:
                line = controller.readline().decode("ascii", errors="ignore").strip()
                fields = line.split(",")

                if len(fields) != 5:
                    continue

                try:
                    values = [int(value) for value in fields]
                except ValueError:
                    continue

                if not all(0 <= value <= 4095 for value in values[:2]):
                    continue
                if not all(value in (0, 1) for value in values[2:]):
                    continue

                udp.sendto(
                    ",".join(map(str, values)).encode("ascii"),
                    (UDP_IP, UDP_PORT),
                )

                x, y, button, joystick_button, tilt = values
                print(f"Sent: X={x} Y={y} Button={button} " f"JoystickButton={joystick_button} Tilt={tilt}")

except KeyboardInterrupt:
    print("\nStopped.")