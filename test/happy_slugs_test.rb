require "test_helper"

class HappySlugsTest < Minitest::Test
  def test_default_configuration
    assert_equal %i[adjective noun verb], HappySlugs::DEFAULT_PATTERN
    assert_equal :slug, Post.happy_slug_attribute
    assert_equal "-", Post.happy_slug_separator
    assert_equal 4, Post.happy_slug_suffix_length
  end

  def test_generates_slug_on_create
    post = Post.create!(title: "Hello")
    assert post.slug.present?
  end

  def test_custom_attribute
    product = Product.create!(name: "Widget")
    assert product.identifier.present?
    assert_nil product[:slug]
  end

  def test_does_not_overwrite_existing_slug
    post = Post.create!(title: "Hello", slug: "custom-slug")
    assert_equal "custom-slug", post.slug
  end

  def test_generates_unique_slugs
    slugs = 50.times.map { Post.create!(title: "Hello").slug }
    assert_equal slugs.length, slugs.uniq.length
  end

  def test_slug_not_regenerated_on_update
    post = Post.create!(title: "Hello")
    original_slug = post.slug
    post.update!(title: "Updated")
    assert_equal original_slug, post.slug
  end
end

class BackfillTest < Minitest::Test
  def setup
    Post.delete_all
  end

  def test_backfill_generates_slugs_for_null_records
    3.times { Post.insert({ title: "Hello" }) }

    assert_equal 3, Post.where(slug: nil).count

    Post.backfill_happy_slugs

    assert_equal 0, Post.where(slug: nil).count
    assert_equal 3, Post.pluck(:slug).uniq.length
  end

  def test_backfill_does_not_overwrite_existing_slugs
    Post.create!(title: "Hello", slug: "keep-me")
    Post.insert({ title: "Hello" })

    Post.backfill_happy_slugs

    assert_equal "keep-me", Post.find_by(slug: "keep-me").slug
    assert_equal 0, Post.where(slug: nil).count
  end

  def test_backfill_returns_count_of_updated_records
    2.times { Post.insert({ title: "Hello" }) }
    Post.create!(title: "Hello", slug: "existing")

    assert_equal 2, Post.backfill_happy_slugs
  end

  def test_backfill_retries_on_collision
    Post.insert({ title: "Hello" })

    attempts = 0
    Post.define_method(:update_column) do |attr, value|
      attempts += 1
      raise ActiveRecord::RecordNotUnique, "UNIQUE constraint failed: posts.slug" if attempts == 1
      super(attr, value)
    end

    Post.backfill_happy_slugs

    assert_equal 0, Post.where(slug: nil).count
  ensure
    Post.remove_method(:update_column)
  end

  def test_backfill_with_custom_attribute
    Product.insert({ name: "Widget" })

    Product.backfill_happy_slugs

    assert Product.first.identifier.present?
  end
end

class CollisionTest < Minitest::Test
  def setup
    Post.delete_all
    ActiveRecord::Base.connection.add_index :posts, :slug, unique: true, if_not_exists: true
  end

  def teardown
    ActiveRecord::Base.connection.remove_index :posts, :slug, if_exists: true
  end

  def test_create_raises_on_manually_set_slug_collision
    Post.create!(title: "Occupier", slug: "taken-slug")

    post = Post.new(title: "Test", slug: "taken-slug")

    assert_raises(ActiveRecord::RecordNotUnique) { post.save! }
  end

  def test_create_raises_on_non_slug_collision
    ActiveRecord::Base.connection.add_index :posts, :title, unique: true, if_not_exists: true

    Post.create!(title: "Taken")

    assert_raises(ActiveRecord::RecordNotUnique) { Post.create!(title: "Taken") }
  ensure
    ActiveRecord::Base.connection.remove_index :posts, :title, if_exists: true
  end
end

class SlugGenerationTest < Minitest::Test
  def test_falls_back_to_suffixed_slug
    HappySlugs::Words::ADVERBS.each { |adverb| Post.insert({ title: "t", slug: adverb }) }

    Post.happy_slug_pattern = %i[adverb]
    post = Post.create!(title: "Hello")
    parts = post.slug.split("-")
    assert_equal 2, parts.length
    assert_match(/\A[a-z0-9]{4}\z/, parts.last)
  ensure
    Post.happy_slug_pattern = HappySlugs::DEFAULT_PATTERN
  end

  def test_suffix_in_pattern
    Post.happy_slug_pattern = %i[adjective noun suffix]
    post = Post.create!(title: "Hello")
    parts = post.slug.split("-")
    assert_equal 3, parts.length
    assert_match(/\A[a-z0-9]{4}\z/, parts.last)
  ensure
    Post.happy_slug_pattern = HappySlugs::DEFAULT_PATTERN
  end

  def test_custom_separator
    Post.happy_slug_separator = "_"
    post = Post.create!(title: "Hello")
    assert_match(/\A[a-z]+(_[a-z]+)+\z/, post.slug)
  ensure
    Post.happy_slug_separator = "-"
  end

  def test_custom_suffix_length
    Post.happy_slug_pattern = %i[adjective noun suffix]
    Post.happy_slug_suffix_length = 8
    post = Post.create!(title: "Hello")
    parts = post.slug.split("-")
    assert_match(/\A[a-z0-9]{8}\z/, parts.last)
  ensure
    Post.happy_slug_pattern = HappySlugs::DEFAULT_PATTERN
    Post.happy_slug_suffix_length = 4
  end

  def test_raises_when_exhausted
    Post.define_method(:happy_slug_patterns) { [] }
    assert_raises(HappySlugs::ExhaustedError) { Post.create!(title: "Hello") }
  ensure
    Post.remove_method(:happy_slug_patterns)
  end
end
