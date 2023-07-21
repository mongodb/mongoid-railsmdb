# Railsmdb for Mongoid

Railsmdb is a command-line utility for creating, updating, managing,
and maintaining Rails applications that use Mongoid and MongoDB for data storage. It is an extension of (and supports all other functionality of) the `rails` command from Ruby on Rails.


## Installation

To install Railsmdb:

```
$ gem install railsmdb
```

This will install a new command, `railsmdb`.


## Usage

The `railsmdb` command may be invoked exactly as you would invoke the `rails` command. For example, to create a new Rails app:

```
$ railsmdb new my_new_rails_app
```

This will create a new folder under the current directory called `my_new_rails_app`, and will populate it with all the scaffolding necessary to begin building your app.

Unlike the `rails` command, however, it will set up the necessary gems and configuration for you to begin your Rails app using the MongoDB database, with Mongoid as the Object-Document Mapper (ODM).

Also, in your new application, there will be a new script in the `bin` folder: `bin/railsmdb`. You'll see `bin/rails` in there as well, but it now links to `bin/railsmdb`.

By default, `railsmdb` will not include ActiveRecord in your new application. If you wish to use both Mongoid and ActiveRecord (to connect to MongoDB and a separate, relational database in the same application), you can pass `--no-skip-active-record`:

```
$ railsmdb new my_new_rails_app --no-skip-active-record
```

This will set up your application to use both Mongoid, and sqlite3 (by default). To start with a different relational database instead, you can pass the `--database` option:

```
$ railsmdb new my_new_rails_app --no-skip-active-record --database=mysql
```

To see a list of all available commands, simply type `railsmdb` without any arguments.

```
$ railsmdb

# alternatively:
$ railsmdb -h
```
