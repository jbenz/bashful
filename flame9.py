#!/usr/bin/env python3
"""
BUNIT ASCII Fire Animation
Direct port of: https://gist.github.com/msimpson/1096950

Usage:
    python3 bunit-fire.py

Controls:
    Press any key to exit
"""

import curses
import random
import sys

def main(screen):
    width = screen.getmaxyx()[1]
    height = screen.getmaxyx()[0]
    size = width * height
    char = [" ", ".", ":", "^", "*", "x", "s", "S", "#", "$"]
    b = [0] * (size + width + 1)
    
    curses.curs_set(0)
    curses.start_color()
    curses.init_pair(1, 0, 0)       # black
    curses.init_pair(2, 202, 0)     # orange (256-color mode)
    curses.init_pair(3, 3, 0)       # yellow
    curses.init_pair(4, 1, 0)       # red
    screen.clear()
    
    frame_count = 0
    
    try:
        while True:
            # Inject heat at bottom
            for _ in range(int(width / 9)):
                b[int((random.random() * width) + width * (height - 1))] = 65
            
            # Spread and decay
            for i in range(size):
                b[i] = int((b[i] + b[i + 1] + b[i + width] + b[i + width + 1]) / 4)
                color = (4 if b[i] > 15 else (3 if b[i] > 9 else (2 if b[i] > 4 else 1)))
                
                if i < size - 1:
                    row = int(i / width)
                    col = i % width
                    
                    if row < height and col < width:
                        try:
                            screen.addstr(
                                row,
                                col,
                                char[(9 if b[i] > 9 else b[i])],
                                curses.color_pair(color) | curses.A_BOLD
                            )
                        except curses.error:
                            pass
            
            screen.refresh()
            screen.timeout(30)
            
            if screen.getch() != -1:
                break
            
            frame_count += 1
    
    except KeyboardInterrupt:
        pass
    finally:
        curses.endwin()
        print(f"\n🔥 BUNIT Animation stopped after {frame_count} frames\n")

if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        print("\nAnimation stopped.\n")
        sys.exit(0)
