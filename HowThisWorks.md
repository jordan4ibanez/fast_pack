# How this works

## 1. Base design

The algorithm that this uses is what I call a tetris pack. It will attempt to assemble your textures as close to the top left as possible. It is doing this to minimize the file size.

The actual ``TexturePacker`` struct is a loosely assembled data container with methods built into it. They are arranged so the entire thing is modular as possible. I wrote this to be as modular and easy to use as possible when working with raw data. You can think of this as a basic component system.

## 2. Components of the TexturePacker

The canvas talked about in documentation exists implicitly. It does not actually exist. The canvas is only defined by 2 variables in the texture packer. The ``width`` and the ``height``. The packer will attempt to keep your texture's ``collision box`` below this boundary and above ``X 0`` and ``Y 0``. You can quite literally think of this as the struct assembling an image from raw data.

The ``collision box`` of a texture is literally the size of it in pixels. If you've enabled ``trim`` in the ``config`` you will notice the excess transparent portions of your textures getting trimmed off the edges of the texture. This is done before the ``collision box`` dimensions are calculated.

The actual ``texture``, which is a ``TrueColorImage`` aka an array of ``ubyte RGBA`` structures built into a class, was created by ``Adam D. Ruppe`` to make things like this a lot easier. The ``collision box`` of the ``texture`` only exists implicitly, these are not actually connected in any sort of manor except through the way the methods of the struct utilize them.

## 3. Packing Algorithm - Tetris Pack

I recommend listening to this as you read this part: https://youtu.be/Ci5squuWW3Q

This will be a simplified example for the sake of not shipping megabytes of data to Dub. 

Let's start off with inserting a new texture in the packer via:
```d
import fast_pack;

void main() {
    TexturePacker!string packer = *new TexturePacker!string(/*default config*/);
    // Here is the insertion
    packer.pack("coolTexture", "my/file/location/image.png");
}
```
What has happened here, is the packer had only one option. The top left of the canvas. We will represent possible choices with ``red``, and set textures with ``white``.

![Illustration 1](https://raw.githubusercontent.com/jordan4ibanez/fast_pack/main/github_assets/illustration_1.png)

The packer wants to get as high up and as far left as it possibly can. When you insert a new ``texture``, it will cycle through all the other ``collision boxes`` for the right and bottom of them as a choice for it's base, which is the top left of it. It sorts these highest to lowest, then iterates them. When it does this, each check it will make sure it is still within the ``canvas`` of the ``texture packer``. Next it checks it's ``collision box`` against every other ``collision box`` to ensure it is not overlapping. If it succeeds at finding a free location, it will score it. If this score is lower than the previous one it sets it's current best score to the current. It also sets the ``best X`` and ``best Y`` so it can be applied. The score is how far away from ``Y`` coordinate ``0`` it is.

So let's add a few more textures.
```d
packer.pack("coolTexture2", "my/file/location/image2.png");
packer.pack("coolTexture3", "my/file/location/image3.png");
```

``coolTexture2`` has two possible choices:

![Illustration 2](https://raw.githubusercontent.com/jordan4ibanez/fast_pack/main/github_assets/illustration_2.png)

It selects the top one because that is closer to ``Y 0``. Now, ``coolTexture3`` has 3 possible choices:

![Illustration 3](https://raw.githubusercontent.com/jordan4ibanez/fast_pack/main/github_assets/illustration_3.png)

Again, this chooses the top most choice because it scored the highest. But what happens when we add another? There is no more room on the right.

```d
packer.pack("fancyTexture", "my/file/location/fancyboi.png");
```

Well, let's see:

![Illustration 4](https://raw.githubusercontent.com/jordan4ibanez/fast_pack/main/github_assets/illustration_4.png)

Ah yes, it only had two feasible choices. But again, it will choose the one on the right, because it scores higher. Now let's fill up the rest of the canvas and add in another with the ``autoResize`` config option enabled. It is enabled by default.

![Illustration 5](https://raw.githubusercontent.com/jordan4ibanez/fast_pack/main/github_assets/illustration_5.png)

The canvas grew! And now we have a free slot to put the other texture. Fantastic.

Now one thing that I have been leaving out of this immense simplification is the fact that it needs to check against **all** possible positions for the best choice. If I illustrated this, most of the picture would be red. 

Hopefully this helps with understanding how it works.