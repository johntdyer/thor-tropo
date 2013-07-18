# Thor::Tropo

Tool used to package released for Chef-Solo installs

## Installation

Add this line to your application's Gemfile:

    gem 'thor-tropo'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install thor-tropo

Include in your Thorfile

include "tropo-tropo"

### Config

Thor-Tropo expects a `.deployer` file and will traverse the path from . through ~ until it finds one.  The .deployer file format is as follows:

    aws_key: xxxx
    aws_secret: xxxxx
    bucket_name: artifacts.bucket.com
    project_name: tropo/12.2.1/cookbooks/functional_deployment
    

Inside your project you can add the following at the root of your `top level cookbook`, or as we like to call it, `deployment model`

`~/my_deployment_model/.deploy`

    project_name: tropo/12.2.1/cookbooks/my_deployment_model
    cookbooks:
      - runtime_server
      - gateway_server    

The important thing to know about .deploy files is that they are implemented as a "first win" type of search pattern.  So if you run Thor for your current working directory it will traverse the path all the way to your home directoy looking for .deployer files.  If it finds one, and it finds a known attribute, it will use that and ignore any higher values.


#### Example

~/.deployer

    bucket_name: foo

~/somewhere/.deployer
    
    bucket_name: bar

If you run thor tropo:package from ~/somewhere/.deployer then the bucket_name value will be bar, becaue that is the first one it found and so it "wins".  The intent here was that you can store certain common config values globally by simply keeping a .deployer file in your home dir, and then only apply certain project specific settings inside source control with your deployment model.  Hacky? Probably.. But it works well for us :) 

## Usage

    jdyer@retina:~ » thor help tropo:package
    Usage:
      thor tropo:package
    
    Options:
      -b, [--berkspath=BERKSPATH]                # Berksfile path
      -V, [--version-override=VERSION-OVERRIDE]  # Provide a version for cookbook archive
      -f, [--force]                              # overwrite any files on s3 without confirmation
      -I, [--iam-auth]                           # Use IAM roles for AWS authorization
      -i, [--ignore-dirty]                       # Will ignore any dirty files in git repo and continue to package cookbooks
      -k, [--keeplock]                           # Respect Berksfile.lock
      -c, [--clean-cache]                        # Delete local Berkshelf cookbook cache
      -n, [--no-op]                              # NO-OP mode, Won't actually upload anything.  Useful to see what would have happened
    
    Package cookbooks using Berkshelf and upload file to s3 bucket


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
