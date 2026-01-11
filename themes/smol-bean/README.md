# smol-bean

A version of the smol theme for Hugo, with [Catppuccin](https://catppuccin.com/) colours applied (and some other tweaks).

smol-bean is based on [smol](https://github.com/colorchestra/smol), which is in turn based on [Blank](https://github.com/Vimux/Blank) created by [Vimux](https://github.com/Vimux).

## Features

- No JavaScript
- No Google spyware or tracking of any kind
- No other external dependencies, embedded fonts or comment sections
- Dark mode support (depending on your OS's setting)

## Installation

In your Hugo site directory, run:

```sh
git submodule add https://github.com/alexhaydock/smol-bean.git themes/smol-bean
```

Then add the following to your `hugo.toml`:
```toml
theme = 'smol-bean'

# Ensure that Hugo doesn't try to use inline CSS for our syntax highlighting.
# (We've got that covered manually in our theme's CSS)
[markup]
  [markup.highlight]
    noClasses = false
```

Changes to the upstream theme can be imported into your local Hugo working directory with:
```sh
git submodule update --remote themes/smol-bean
```
