### Description
This is a backward incompatible fork of https://github.com/djberg96/interface
It provides interfaces, traits and runtime interface checks in Ruby 

### Installation
`gem install rubycube` OR
`gem rubycube` in your Gemfile

### Theory

http://web.archive.org/web/20061209142330/http://www.iam.unibe.ch/~scg/Archive/Papers/Scha02bTraits.pdf

### Synopsis
See [this annotated example](examples/demo.rb)

### General Notes

Since runtime checks are meant to be invoked for every invocation of a method,
there is a runtime overhead associated which may not be desirable in
production. Hence these checks are guarded by an environment variable
`RUBY_CUBE_TYPECHECK`. Unless this variable is set to 1, the runtime
checks are not executed

### Runtime performance of check methods

On a Macbook Pro 2.4 GHz Intel Core i5 machine, enabling runtime checks costs
about 1 second for every million calls. YMMV.  It is advisable to benchmark for
your code to determine if the overhead is acceptable in your enviroment.

### Developer's Notes (from the original repository)
  A discussion on IRC with Mauricio Fernandez got us talking about traits.
  During that discussion I remembered a blog entry by David Naseby. I 
  revisited his blog entry and took a closer look:

  http://ruby-naseby.blogspot.com/2008/11/traits-in-ruby.html

  Keep in mind that I also happened to be thinking about Java at the moment
  because of a recent job switch that involved coding in Java. I was also
  trying to figure out what the purpose of interfaces were.

  As I read the first page of David Naseby's article I realized that,
  whether intended or not, he had implemented a rudimentary form of interfaces
  for Ruby. When I discovered this, I talked about it some more with Mauricio
  and he and I (mostly him) fleshed out the rest of the module, including some
  syntax improvements. The result is syntax and functionality that is nearly
  identical to Java.

  I should note that, although I am listed as the author, this was mostly the
  combined work of David Naseby and Mauricio Fernandez. I just happened to be
  the guy that put it all together.

### Acknowledgements (from the original repository)
  This module was largely inspired and somewhat copied from a post by
  David Naseby (see URL above). It was subsequently modified almost entirely
  by Mauricio Fernandez through a series of discussions on IRC.
	
### Copyright
  (C) 2004-2016 Daniel J. Berger
  (C) 2016 Aditya Godbole
  All rights reserved.
	
### Warranty
  This package is provided "as is" and without any express or
  implied warranties, including, without limitation, the implied
  warranties of merchantability and fitness for a particular purpose.
	
### License
  Artistic 2.0
	
### Author
  Daniel J. Berger
  Aditya Godbole
