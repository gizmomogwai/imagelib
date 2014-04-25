# Imagelib

This is a little gem to support my photo workflow.

## Installation

    gem install imagelib

## Usage

You just have to add a .imagelib file to your home which is a yaml file describing
where images can be found and what prefix images from these source should get.
example:

    -
      path: /Volumes/MyGoodCam
      prefix: hq_
    -
      path: /Volumes/MyLittleCam
      prefix: lq_

this means that pictures that can be found in /Volumes/MyGoodCam are copied to ~/Pictures/ImageLib with the prefix hq_ and pictures that can be found in /Volumes/MyLittleCam are copied to ~/Pictures/ImageLib with the prefix lq_.

After that you are ready to launch the executable

    $ copy2lib

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
