# Happy Slugs

Pleasant, random, human-readable identifiers for ActiveRecord models.

```ruby
class Project < ApplicationRecord
  has_happy_slugs
end

Project.create!.slug #=> "brave-dogs-jump"
```

## Installation

Add to your Gemfile:

```ruby
gem "happy_slugs"
```

The model's table needs a string column for the slug (defaults to `slug`):

```ruby
add_column :projects, :slug, :string, index: { unique: true }
```

## Usage

```ruby
class Project < ApplicationRecord
  has_happy_slugs              # stores in :slug
end

class Invoice < ApplicationRecord
  has_happy_slugs :identifier  # stores in :identifier
end
```

Slugs are generated on create. Pre-set values are preserved:

```ruby
Project.create!.slug                          #=> "clever-foxes-run"
Project.create!(slug: "my-slug").slug         #=> "my-slug"
```

## How it works

You choose a pattern of word types (default: `[:adjective, :noun, :verb]`). On create, the generator batch-generates 10 candidates matching your pattern, filters out any that already exist in the database, and picks one at random.

If all 10 collide — meaning your pattern's keyspace is getting crowded — it automatically falls back to appending a 4-character alphanumeric suffix (e.g., `brave-dogs-jump` becomes `brave-dogs-jump-x7b2`). This suffix multiplies the base keyspace by 1,679,616 (36^4), so even a two-word pattern has over 100 billion combinations with its suffix fallback.

| Pattern | Example | Combinations | Suffix fallback after | With suffix |
|---------|---------|-------------:|----------------------:|------------:|
| `adjective noun` | `happy-cats` | 60,000 | ~56,000 | ~100 billion |
| `adjective noun verb` (default) | `brave-dogs-jump` | 15,000,000 | ~14,000,000 | ~25 trillion |
| `adjective noun verb adverb` | `clever-foxes-run-quickly` | 300,000,000 | ~280,000,000 | ~504 trillion |
| `adjective adjective noun verb` | `bold-sunny-bears-dance` | 3,000,000,000 | ~2,800,000,000 | ~5 quadrillion |

**Suffix fallback after** is the approximate number of records at which there's a >50% chance that 10 random candidates all collide, triggering the suffix. This happens when the table reaches ~93% of the pattern's keyspace.

Word lists: 200 adjectives, 300 nouns, 250 verbs, 20 adverbs. Suffix is a random 4-character alphanumeric string.

## Choosing a pattern

The default `[:adjective, :noun, :verb]` gives you 15 million suffix-free slugs — plenty for most tables. If you want shorter slugs and don't need that much headroom, use a two-word pattern. If you need more, add an adverb or a second adjective:

```ruby
class Project < ApplicationRecord
  has_happy_slugs  # 15 million suffix-free — the default
end

class Label < ApplicationRecord
  has_happy_slugs pattern: %i[adjective noun]  # 60,000 suffix-free — fine for small tables
end
```

Shorter patterns produce more memorable slugs. Even after the suffix kicks in, slugs stay readable — `brave-dogs-jump-x7b2` is still friendlier than a UUID.

If you'd prefer every slug to have a suffix for consistency, include `:suffix` in the pattern directly. The automatic fallback is skipped when the pattern already contains a suffix:

```ruby
class Order < ApplicationRecord
  has_happy_slugs pattern: %i[adjective noun suffix]  # always "happy-cats-x7b2"
end
```

Available word types: `:adjective`, `:noun`, `:verb`, `:adverb`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `pattern:` | `[:adjective, :noun, :verb]` | Word types that make up the slug |
| `separator:` | `"-"` | Character between slug parts |
| `suffix_length:` | `4` | Length of the alphanumeric suffix |

```ruby
class Project < ApplicationRecord
  has_happy_slugs separator: "_"              #=> "brave_dogs_jump"
  has_happy_slugs suffix_length: 6            #=> "brave-dogs-jump-x7b2m9" (on fallback)
end
```

## Backfilling existing records

If you're adding Happy Slugs to a table that already has data:

```ruby
Project.backfill_happy_slugs  #=> 42 (number of records updated)
```

This sets slugs on all records where the slug column is `nil`, without touching existing values.
