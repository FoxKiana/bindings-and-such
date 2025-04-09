
# BC3 - C bindings for C3

BC3 - is a repository which contains a bunch of automatically generated bindings, powered by [bindgen.c3l](https://github.com/vssukharev/bindgen.c3l).

## Setup

To install bindings to library **foo**, simply copy **foo.c3l** located in **libs** to your project libraries sdirectory and set **foo** as dependenncy.

## Regenerate bindings

First of all, install **libclang** required by [bindgen.c3l](https://github.com/vssukharev/bindgen.c3l), then simply run `c3c run` from root directory.

