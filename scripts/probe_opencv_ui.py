#!/usr/bin/env python3
"""! @file probe_opencv_ui.py
@brief Print the current OpenCV UI and video backend view.
@details This helper is intentionally lightweight so board-local UX debugging
can confirm whether the deployed OpenCV build exposes HighGUI and videoio
backends in the current shell session.
"""

import os
import sys

import cv2


def main() -> int:
    """! Print OpenCV runtime/backend diagnostics."""
    print(f"cv2_version={cv2.__version__}")
    print(f"DISPLAY={os.environ.get('DISPLAY', '<unset>')}")
    print(f"WAYLAND_DISPLAY={os.environ.get('WAYLAND_DISPLAY', '<unset>')}")
    print(f"XDG_SESSION_TYPE={os.environ.get('XDG_SESSION_TYPE', '<unset>')}")
    if hasattr(cv2, "currentUIFramework"):
        try:
            print(f"currentUIFramework={cv2.currentUIFramework() or '<none>'}")
        except Exception as exc:  # pragma: no cover - diagnostic helper only
            print(f"currentUIFramework_error={exc}")
    if hasattr(cv2, "videoio_registry"):
        try:
            print(f"videoio_backends={cv2.videoio_registry.getBackends()}")
        except Exception as exc:  # pragma: no cover - diagnostic helper only
            print(f"videoio_registry_error={exc}")
    build_info = cv2.getBuildInformation()
    for line in build_info.splitlines():
        if line.strip().startswith("GUI:") or line.strip().startswith("Video I/O:"):
            print(line.rstrip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
