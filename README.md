# roquefort

<img src="https://cdn.hackclub.com/01a13cfe-f7a6-7a67-853d-5b0923e0a970/roquefort-757581-2940x1912.png" width="800">

a shader for [wpr](https://github.com/maxwofford/wpr), the wallpaper manager.

a liquid of hues under a pixelated grain. inspired by [RoquefortCheese's fluidsim](https://github.com/RoquefortCheese/fluidsim)

```sh
brew tap maxwofford/wpr && brew install wpr   # if you don't have wpr yet
wpr install maxwofford/roquefort
wpr gen roquefort                             # a new one, set as your wallpaper
wpr enable roquefort                          # add it to your rotation
```

## local development

wanna clone and iterate on the design?

```sh
git clone https://github.com/maxwofford/wpr-roquefort
wpr install ./wpr-roquefort
wpr gen roquefort
```
