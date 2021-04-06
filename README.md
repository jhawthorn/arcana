# Arcana 🧙‍♂️

This project is an attempt to write a pure Ruby MIME type/file type sniffer using the same [`magic` rule database](https://man.archlinux.org/man/magic.5) as used by [file and libmagic](https://github.com/file/file). 

## Current Status

**Not yet production ready**

It _somewhat_ works, but has missed implementing quite a few rules. Not yet safe to be run against arbitrary user input (can be made to infinite loop).

## License

Similarly to `file`, Arcana is licensed under a [2-Clause BSD License](./LICENSE)

## Similar libraries

* [Marcel](https://github.com/rails/marcel) Pure Ruby MIME type detection using a database derived from Apache Tika
* [ruby-magic](https://github.com/kwilczynski/ruby-magic) libmagic C bindings for Ruby

## See also
