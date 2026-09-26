# kitty

## Windows open maximized instead of tiled

**Symptom:** every new kitty window opens filling the screen (maximized) instead
of the normal tiled size, no matter how the previous window was left.

**Cause:** kitty's default `ctrl+shift+enter` maximizes the OS window, and
`remember_window_size` (default `yes`) persists both the window size *and* the
maximized state between invocations. So one accidental maximize was inherited by
every kitty launched after it.

**Fix** — in `kitty.conf`:

```
remember_window_size no
```

New windows then start at `initial_window_width` / `initial_window_height`
(kitty's defaults are `640` x `400` px). To pick a different default, set them
explicitly; a `c` suffix interprets the value as cells instead of pixels:

```
initial_window_width  120c
initial_window_height 40c
```

### Notes

- The option was renamed. Older dotfile snippets use `remember_window_state`,
  which **does not exist** in kitty 0.49.1 and is silently ignored. The current
  name is `remember_window_size`.
- `remember_window_position` is a separate option and defaults to `no`.
- Verify which options kitty actually parsed:

  ```
  kitty +runpy "
  from kitty.config import load_config
  c = load_config('$HOME/.config/kitty/kitty.conf')
  print(c.remember_window_size)
  "
  ```

  Note the first argument is the config *path* — `load_config` takes `*paths`, so
  `load_config('NONE', ...)` silently loads no config at all and always prints
  the default.
