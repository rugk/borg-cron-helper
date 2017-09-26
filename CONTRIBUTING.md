# How to contribute?

Thanks for your interest in contributing to this project! :+1: :tada:

The good news is: Just send your PR.

## Some things

* This should stay a simple script, don't add too much to it. We don't want [feature creep](https://en.wikipedia.org/wiki/Feature_creep) here.
* Do make use of the [`.editorconfig`](.editorconfig) file. Either manually look what indentation, etc. to use, or [use a plugin](http://editorconfig.org/#download) for your prefered editor (recommend).
* Before adding larger features or changing too much things, please open an issue to discuss it prior to putting work into it.
* Use [shellcheck](https://www.shellcheck.net/) to check your changes. The unit tests will tests this and fail if any shellcheck issues are found. (Use [comments](https://github.com/koalaman/shellcheck/wiki/Directive) to ignore errors, **if you have very strong reasons**.)


## Tests

Please use the automated tests to check that your changes are okay. You can run them locally, but they are also run automatically by Travis-CI.
For more info see [the test readme](tests/README.md).
Fell free to adjust or add tests, if needed/useful.
