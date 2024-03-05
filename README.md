<p align="center">
  <img src="https://github.com/autumncommunity/b2m_binary/raw/master/img/b2m.png" />
</p>

<h1 align="center">
    B2M
</h1>

<h3 align="center">
    Garry's Mod binary modules manager
</h3>
<br>

B2M - Binary Module Manager.

| Part of B2M | Description |
|:---:|:---:|
| [b2m_binary](https://github.com/autumncommunity/b2m_binary) | Main Binary Module. Adds functions needed for b2m_lua to Lua. |
| [b2m_menu](https://github.com/autumncommunity/b2m_menu) | Binary module for add gameevent.Listen function |

### Working principle
The client downloads B2M once from the site, and installs it according to the guide on the site.

Then, if on the server, to which the player will connect, also will be B2M, then on the client's computer will download all dependencies (binary modules), which installed the server.

Also B2M can be used simply as a package manager of binary modules only for the server.

# Use examples
### Server console:
##### Binary module installation
```bash
b2m install <name> <version> [flags]

b2m install chttp * // * - newest version
b2m install chttp 1.0.0 // 1.0.0 version
b2m install chttp * --server-only // install CHTTP module only on server
```

### Binary module remove
```bash
b2m remove <name>

b2m remove chttp
```

# Lua side

```lua
-- Including binary module

if b2m and b2m.Require("chttp") then
  print("chttp binary loaded")
else
  error("couldn't load chttp module! (b2m not installated/b2m binaries loading disabled/chttp module not found")
end
```
