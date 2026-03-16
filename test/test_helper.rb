require "bundler/setup"
require "active_record"
require "minitest/autorun"
require "happy_slugs"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(IO::NULL)

ActiveRecord::Schema.define do
  create_table :posts do |t|
    t.string :slug
    t.string :title
  end

  create_table :products do |t|
    t.string :identifier
    t.string :name
  end

  create_table :articles do |t|
    t.string :slug
    t.string :title
  end
end

class Post < ActiveRecord::Base
  has_happy_slugs
end

class Product < ActiveRecord::Base
  has_happy_slugs :identifier
end

class Article < ActiveRecord::Base
  has_happy_slugs pattern: %i[adjective noun]
end
