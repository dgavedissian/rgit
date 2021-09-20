# Rgit

A reimplementation of some Git commands using Ruby. The following commands are implemented:

- `init`
- `checkout` (slightly modified - 2nd parameter specifies directory to write files to, must be empty)
- `log`
- `tag` (listing tags and creating a tag, either annotated or not)
- `branch` (listing branches only)
- `help`
- `cat-file`
- `hash-object`
- `ls-tree`
- `show-ref`

Sources:
- https://github.com/git/git/tree/master/Documentation/technical
- https://wyag.thb.lt/

## Installation

Run `./bin/setup` to install all the correct dependencies to `./vendor`. This project assumes you have Ruby and `bundle` available
on your PATH. `bundle` can be installed by running `gem install bundler` and ensuring the Gems binary dir is in your PATH.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dgavedissian/rgit.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
