# AWS Account Manager

The AWS Account Manager is a shell function that manages multiple AWS accounts and their credentials. It handles setting
all of the different variables required by the AWS command line tools (which are inconsistent). It also provides a
mechanism for running commands under a different account without switching your local shell's context.

## Installation

Installation of the script is very simple:

```
$ curl -L https://raw.github.com/jlogsdon/aam/master/aam.sh > ~/.aam.sh
$ echo 'source ~/.aam.sh' >> ~/.bash_profile # Or .zsh_profile if you use zshell
$ exec $SHELL
```

You should now be able to call `aam`.

## Usage

```
AWS Account Manager

Usage:
  aam help                      Show this message
  aam create <account>          Create a new AWS account
  aam use <account>             Use the named AWS account
  aam do <account> <command...> Use the named AWS account
  aam default <account>         Set the default account
  aam list                      Show all available accounts
```

### Creating an Account

Once AAM has been installed you can start by creating and editing new account:

```
$ aam create personal
$ $EDITOR $AAM_STORE/personal
```

Account files are simply a list of variables which are sourced whenver you switch accounts. Anything goes as long as
your shell can process the file. At a bare minimum the file should look like this:

```
export AWS_ACCESS_KEY=some_access_key_id
export AWS_SECRET_KEY=some_secret_access_key
```

The next section describes all of the variables AAM works with, any of which can be defined explicitly in your account
definition.

## Variables

Amazon's official command line tools have a huge problem with consistency. Different variables are read and, in some
cases, a credentials file is required. The main goal for AAM, outside of making account switching simple, is to handle
the setup of these variables and files automatically.

* `AWS_ACCESS_KEY` and `AWS_SECRET_KEY` are expected by AAM and several of the command line tools.
* `AWS_ACCESS_KEY_ID` is set to `AWS_ACCESS_KEY`.
* `AWS_SECRET_ACCESS_KEY` is set to `AWS_SECRET_KEY`.
* `AWS_CREDENTIALS_FILE` is, by default, set to `AAM_DEFAULT_EC2_CREDS`. You may override it in your account if you
  wish.
* `EC2_PRIVATE_KEY` should be set to the path of your private key. This is not handled magically and should be set in
  either your account or globally in your profile.
* `EC2_CERT` is similar to the above but should point to your certificate file.

## Customization

AAM uses it's own variables to define default accounts and where files should be stored. These can be overridden, but
sane defaults are provided.

* `AAM_STORE` is the folder where account definitions are stored (`$HOME/.aam`).
* `AAM_DEFAULT_FILE` is the file where the default account is stored (`$AAM_STORE/.default`).
* `AAM_DEFAULT_EC2_CREDS` is the default for `AWS_CREDENTIALS_FILE` (`$HOME/.ec2.creds`).

