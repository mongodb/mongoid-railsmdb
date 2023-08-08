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


### Setting up railsmdb and Mongoid in an established Rails app

If you want to add `railsmdb` to an existing (non-Mongoid) Rails app, and add Mongoid configuration as well, you can use `railsmdb setup`:

```
$ railsmdb setup
```

This must be run from the root directory of a Rails project. It will replace `bin/rails` with `bin/railsmdb`, add the `mongoid.yml` configuration file and the `mongoid.rb` initializer, and add the necessary gem entries to the `Gemfile`.

**Note:** it is recommended to run this command in a branch, so that you can easily experiment with the changes and roll them back if necessary.


### Generating Mongoid models

You can use `railsmdb` to generate stubs for new Mongoid models. From within a project:

```
$ bin/railsmdb generate model person
```

This will create a new model at `app/models/person.rb`:

```ruby
class Person
  include Mongoid::Document
  include Mongoid::Timestamp
end
```

You can specify the fields of the model as well:

```ruby
# bin/railsmdb generate model person name:string birth:date

class Person
  include Mongoid::Document
  include Mongoid::Timestamp
  field :name, type: String
  field :birth, type: Date
end
```

You can instruct the generator to make the new model a subclass of another, by passing the `--parent` option:

```ruby
# bin/railsmdb generate model student --parent=person

class Student < Person
  include Mongoid::Timestamp
end
```

And if you need to store your models in a different collection than can be inferred from the model name, you can specify `--collection`:

```ruby
# bin/railsmdb generate model course --collection=classes

class Course
  include Mongoid::Document
  include Mongoid::Timestamp
  store_in collection: 'classes'
end
```
