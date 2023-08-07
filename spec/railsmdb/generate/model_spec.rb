# frozen_string_literal: true

require 'spec_helper'

app_name = 'test_app'

describe 'railsmdb generate model' do
  when_running :railsmdb, 'new', app_name, clean: true do
    it_succeeds

    within_folder app_name do
      when_running :railsmdb, 'generate', 'model', 'person' do
        it_succeeds

        it_emits_file 'app/models/person.rb',
                      containing: [ "class Person\n", 'include Mongoid::Document', 'include Mongoid::Timestamps' ],
                      without: 'store_in'
        it_emits_file 'test/models/person_test.rb'
        it_emits_file 'test/fixtures/people.yml'
      end

      when_running :railsmdb, 'generate', 'model', 'student', '--parent=person' do
        it_succeeds

        it_emits_file 'app/models/student.rb',
                      containing: [ "class Student < Person\n", 'include Mongoid::Timestamps' ],
                      without: [ 'include Mongoid::Document', 'store_in' ]
        it_emits_file 'test/models/student_test.rb'
        it_emits_file 'test/fixtures/students.yml'
      end

      when_running :railsmdb, 'generate', 'model', 'course', '--collection=classes' do
        it_succeeds

        it_emits_file 'app/models/course.rb',
                      containing: 'store_in collection: \'classes\''
        it_emits_file 'test/models/course_test.rb'
        it_emits_file 'test/fixtures/courses.yml'
      end

      when_running :railsmdb, 'generate', 'model', 'book', 'title:string',
                   'started:time', 'good:boolean', 'review:text' do
        it_succeeds

        it_emits_file 'app/models/book.rb',
                      containing: [
                        'field :title, type: String',
                        'field :started, type: Time',
                        'field :good, type: Mongoid::Boolean',
                        'field :review, type: String'
                      ]
      end

      when_running :railsmdb, 'generate', 'model', 'todo', '--no-timestamps' do
        it_succeeds

        it_emits_file 'app/models/todo.rb',
                      without: 'include Mongoid::Timestamps'
      end
    end
  end
end
