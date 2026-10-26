# roquefort

<img src="https://cdn.hackclub.com/01a179ad-e4bf-79fd-81c9-2308af605244/roquefort-757581-1920x1249.png" width="800">

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
