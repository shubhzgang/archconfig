import colorsys
import sys

def increase_saturation(hex_color, factor=1.5):
    r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
    r_norm, g_norm, b_norm = r / 255.0, g / 255.0, b / 255.0
    h, s, v = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
    s = 0.85
    #print(h, s, v)
    new_r, new_g, new_b = colorsys.hsv_to_rgb(h, s, v)
    new_r = int(new_r * 255)
    new_g = int(new_g * 255)
    new_b = int(new_b * 255)
    color_str = f'{new_r:02x}{new_g:02x}{new_b:02x}'
    print(color_str)
    return color_str

if __name__ == "__main__":
    #print(len(sys.argv))
    if len(sys.argv) < 2:
        print("Usage: python saturate.py <hex_color> [factor]")
        sys.exit(1)
    
    # Read arguments from the command line
    color_arg = sys.argv[1]
    # Use a default factor of 1.5 if not provided
    factor_arg = float(sys.argv[2]) if len(sys.argv) > 2 else 1.5
    
    increase_saturation(color_arg, factor_arg)
