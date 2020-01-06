# Imagelib

This is a little gem to support my photo workflow.

## Installation

    gem install imagelib

## Usage

You just have to add a .imagelib file to your home which is a yaml file describing
where images can be found and what prefix images from these source should get.
example:

    -
      path: file:///Volumes/MyGoodCam
      prefix: my_good_cam_
    -
      path: http://192.168.43.30/
      prefix: phone_

With this config photos are copied from two sources:
 - pictures from the local filesystem are copied over with the prefix my_good_cam_
 - pictures from an android phone with getpix running on ip 192.168.43.30 are copied over with prefix phone_
All the pictures are put to ~/Pictures/ImageLib/year/month/year-month-day/ folder.

After that you are ready to launch the executable

    $ copy2lib

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
