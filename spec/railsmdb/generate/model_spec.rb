# frozen_string_literal: true

require 'spec_helper'

app_name = 'test_app'

describe 'railsmdb generate model' do
  when_running_railsmdb 'new', app_name do
    it_succeeds

    within_folder app_name do
      when_running_bin_railsmdb 'generate', 'model', 'person' do
        it_succeeds

        it_emits_file 'app/models/person.rb',
                      containing: [ "class Person\n", 'include Mongoid::Document', 'include Mongoid::Timestamps' ],
                      without: 'store_in'
        it_emits_file 'test/models/person_test.rb'
        it_emits_file 'test/fixtures/people.yml'
      end

      when_running_bin_railsmdb 'generate', 'model', 'student', '--parent=person' do
        it_succeeds

        it_emits_file 'app/models/student.rb',
                      containing: [ "class Student < Person\n", 'include Mongoid::Timestamps' ],
                      without: [ 'include Mongoid::Document', 'store_in' ]
        it_emits_file 'test/models/student_test.rb'
        it_emits_file 'test/fixtures/students.yml'
      end

      when_running_bin_railsmdb 'generate', 'model', 'course', '--collection=classes' do
        it_succeeds

        it_emits_file 'app/models/course.rb',
                      containing: 'store_in collection: \'classes\''
        it_emits_file 'test/models/course_test.rb'
        it_emits_file 'test/fixtures/courses.yml'
      end
    end
  end
end
