# Python Test Framework vs. Bash Framework

## Python

### Pros 

* More versatile language than Bash
* Just as portable, if not moreso
* Can leverage libraries for things such as backoffs, etc. 
* We already use python within the CI system
* Can be more generic than bash
* Better logging controls
* First class exception handling
* Can be designed to make adding tests easier


### Cons

* Requires rewriting a non-trivial amount of code
* Could be overkill, do we need this type of framework?
* Slight overlap with Snafu
    * They do, however, serve different purposes. 
