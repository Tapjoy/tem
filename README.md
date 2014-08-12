# The Environment Manager

Environment Manager is a shell function that assists in managing multiple environments for a Platform (eg. AWS and
Chef). There is no predefined list of supported Platforms, any platform name may be given at any point in time. By
default each Platform only manages setting and unsetting of environment variables defined in Profiles. Through the use
of hooks or custom command implementations it is possible to define more specific functionality for a given Platform
(see AWS and Chef implementations).

## Requirements

A modern shell is required for this to operate. It has been tested on Bash 4.x and ZSH 5.x.

**This script will not work with Bash 3.x, which OSX ships by default**

### Upgrading Bash on OSX

Using homebrew, follow these steps:

```
$ brew install bash
$ sudo $EDITOR /etc/shells # Add /usr/local/bin/bash to the list of shells.
$ chsh -s /usr/local/bin/bash
```

You will likely need to logout of your desktop completely for new terminal shells to start with the correct version. To
check the version of bash you are using run the following:

```
$ $SHELL --version
```

## Installation

Installation of the script is very simple (*note: while this is a private repository you will have to grab the raw URL
from GitHub yourself (a token is required)*):

```
$ curl -L https://raw.github.com/tapjoy/tem/master/em.sh > ~/.em.sh
$ cat >> ~/.bash_profile <<EOC # Or .zsh_profile if you use zsh
source $HOME/.em.sh
em init # Loads default Profiles for each Platform found
EOC
```

Reload your shell and you will now have access to the `em` function.

### Suggested Aliases

AWS is an oft-used Platform in Environment Manager. To ease the use of this Platform (and provide backwards
compatibility with the old [AAM](https://github.com/jlogsdon/aam) utility) we suggest the following alias:

```shell
alias aam='em aws'
```

## Commands

```
Usage: em [platform] [command]

Global Commands (no platform)
  init                      Run init for all platforms found under $EM_STORE
  list                      Run list for all platforms found under $EM_STORE

Default Platform Commands
  init                      Load the default profile if one is set
  create <profile>          Create an profile for this platform
  remove <profile>          Remove an profile from this platform
  list                      List all profiles for this platform
  use <profile>             Use the given profile for the current shell
  unset                     Unset the current profile and remove all variables
  do <profile> <command...> Run a command under the given profile
  default <profile>         Show all available profiles
```

## Customization

EM uses it's own variables to define where the em.sh script itself lives and where EM Platforms and Profiles are stored.

* `EM_SCRIPT` is the location of em.sh (`$0`)
* `EM_STORE` is the folder where account definitions are stored (`$HOME/.em`).

## Platforms

Platform names can be any word (that is, any string of characters without whitespace). EM includes hooks and custom
commands for two Platforms: `aws` which is analogous with the AAM script EM replaces; and `chef` which manages loading
and unloading custom `knife.rb` override files.

Throughout this file we will reference two `PLATFORM_*` variables that are defined as such: `PLATFORM_NAME` is
lower-case normalized named used for store paths and output; `PLATFORM_CODE` is the upper-case normalized name used for
variable names.

There are several Platform specific variables EM uses for configuration:

 * `EM_{$PLATFORM_CODE}_STORE` - Where EM will store the profiles for this platform. Note that moving the platform store
    outside of the default location will make global commands unable to find the platform. (default: `$EM_STORE/$PLATFORM_NAME`)
 * `EM_{$PLATFORM_CODE}_DEFAULT_FILE` - Where the file containing the default profile lives (default: `STORE/.default`)
 * `EM_{$PLATFORM_CODE}_DEFAULT` - The default profile to load. If set the `DEFAULT_FILE` variable will be ignored;
   otherwise the `DEFAULT` will be set to the contents of that file.
 * `EM_{$PLATFORM_CODE}_PROFILE` - Which profile EM currently has (or at least thinks) is loaded into the environment.

## Profiles

In general, a profile is simply a shell script that will be sourced by EM. To assist in unsetting these variables later,
we suggest all variables defined use the `export VARIABLE_NAME=content` format. As we are simply sourcing the file into
your current shell, it is also possible to include any code that would run under your shell. It is important to note
that any of this extra code will not be automatically undone (if needed) when changing or unloading profiles.

In the specific case of Chef, Profiles are actually Ruby files that will be symlinked to
`$HOME/.chef/overrides/knife-${profile}.rb`.

### Defaults

For a generic Platform we create an empty Profile by default. It is possible to define a function which can add default
content to this file. To use this behavior, define a function: `_em_defaults_${PLATFORM_NAME}`. This function is passed
in the path to the Profile store file and must manually write out to that file. See `_em_defaults_aws` for an example.

## Hooks

Hooks are provided for a couple commands to allow easy extension of functionality. Hooks are defined as functions and
follow the naming convention of `_em_hook_${PLATFORM_NAME}_${HOOK_NAME}`. Currently only one implementation of each hook
is supported per Platform. The following hooks are provided for your enhancement needs (content in parentheticals are
arguments passed into the hook):

 * `set_variables` - Called before any command is run and after the `EM_VARS` have been setup.
 * `create($profile, $store_file)` - Called *after* a Profile has been created.
 * `remove($profile, $store_file)` - Called *after* a Profile has been removed.
 * `use($profile, $store_file)` - Called *after* a Profile has been loaded.
 * `unset($profile, $store_file)` - Called *after* a Profile has been unloaded.
 * `do($profile, $store_file)` - Called *before* the given command is executed under the specified profile.

```shell
_em_hook_myp_create() {
  echo "Profile $1 created!"
}
```

## Custom Command Handlers

While every command listed above has default implementations it is possible to provide a custom implementation for a
specific Platform. It is also possible to define completely new commands using this convention. Custom command handlers
should be named after the following convention: `_em_command_${PLATFORM_NAME}_${COMMAND_NAME}`. You can also define a
generic (runs for any platform) command in the same manner, except the naming convention is:
`_em_command_${COMMAND_NAME}`.

```shell
_em_command_myp_do() {
  # Custom `do` command for the `myp` Platform
}
_em_command_debug() {
  # Custom `debug` command for *every* Platform
}
```

# Platform Details

The custom implementation details for AWS and Chef are as follows.

## AWS

The AWS command line tools are inconsistent in where it expects credentials to be defined. To assist the user in this
chaos we provide automatic variable mapping for AWS Profiles.

### AWS Tool Variables

By default, we configure the shell to look in `/usr/share` for the AWS tools and `$HOME/.ec2.creds` for a credentials
file. You can override these settings by setting the following variables:

 * `EC2_HOME` - Where the ec2 tools live.
 * `AWS_AUTO_SCALING_HOME` - Where the auto scaling tools live.
 * `AWS_CLOUDWATCH_HOME` - Where the cloudwatch tools live.
 * `AWS_DEFAULT_CREDENTIALS_FILE` - Where the default credentials file lives (can be set on a per-Profile basis).

### Variable Mapping

We expect two variables to be set in your AWS profile: `AWS_ACCESS_KEY` and `AWS_SECRET_KEY`. These two variables are
then mapped to `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` automatically when a Profile is loaded.

If the Profile does not define an `AWS_CREDENTIALS_FILE` variable it will be set to `AWS_DEFAULT_CREDENTIALS_FILE`.

### Credentials File

Some AWS tools require the Credentials File. The location of this is set using one of two variables described above, and
the contents are automatically populated with:

```shell
AWSAccessKeyId=$AWS_ACCESS_KEY
AWSSecretKey=$AWS_SECRET_KEY
```

## Chef

Chef is a special snowflake in that it does not manage environment variables, but instead handles symlinking Profiles to
a chef overrides directory. This is a case where custom command implementations are heavily used.

The chef overrides directory is located at `$HOME/.chef/overrides`.
