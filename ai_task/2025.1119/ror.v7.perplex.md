Perfect! Now I have enough context. Let me provide a comprehensive implementation plan for a custom 1..n arity association using roaringbitmap64 as the foreign key type.

## Implementation Plan: Custom Association with RoaringBitmap64 Foreign Key

Based on your Rails 7.2 + PostgreSQL 17 stack and the `pg_roaringbitmap` extension, here's a detailed plan for implementing a custom association type that uses `roaringbitmap64` for efficient 1-to-many relationships.

### **Conceptual Overview**

Traditional Rails associations use integer foreign keys (1-to-1) or join tables (many-to-many). Your custom association would store multiple related IDs directly in a single `roaringbitmap64` column, combining the efficiency of bitmaps with native association semantics.

**Example use case:**
```ruby
class User < ApplicationRecord
  has_many_bitmap :viewed_posts, class_name: "Post"
end

# Stores post IDs as compressed bitmap: {1, 5, 100, 1000, ...}
# user.viewed_posts => [Post(1), Post(5), Post(100), ...]
```

***

### **Phase 1: Foundation - PostgreSQL Setup**

#### 1.1 Extension Installation
```ruby
# db/migrate/XXXXXX_enable_roaringbitmap.rb
class EnableRoaringbitmap < ActiveRecord::Migration[7.2]
  def up
    enable_extension 'roaringbitmap64'
  end

  def down
    disable_extension 'roaringbitmap64'
  end
end
```

#### 1.2 Column Definition
```ruby
# Example migration for bitmap foreign key
class AddViewedPostsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :viewed_post_ids, :roaringbitmap64, 
               default: "'{}'::roaringbitmap64"
  end
end
```

***

### **Phase 2: ActiveRecord Type Registration**

Create a custom ActiveRecord type to handle roaringbitmap64 serialization/deserialization.

```ruby
# lib/active_record/type/roaring_bitmap.rb
module ActiveRecord
  module Type
    class RoaringBitmap64 < ActiveRecord::Type::Value
      def type
        :roaringbitmap64
      end

      # Deserialize from database (bytea format) to Ruby array
      def deserialize(value)
        return [] if value.nil? || value.empty?
        
        # pg_roaringbitmap returns bytea, convert to array of integers
        result = ApplicationRecord.connection.execute(
          "SELECT rb_to_array(#{ApplicationRecord.connection.quote(value)}::roaringbitmap64)"
        )
        result.first['rb_to_array'] || []
      end

      # Serialize Ruby array to roaringbitmap64
      def serialize(value)
        return "'{}'::roaringbitmap64" if value.nil? || value.empty?
        
        array_literal = "{#{Array(value).join(',')}}"
        "rb64_build('#{array_literal}')"
      end

      # Cast input to array of integers
      def cast(value)
        case value
        when Array
          value.map(&:to_i)
        when String
          value.split(',').map(&:to_i)
        when Integer
          [value]
        else
          []
        end
      end
    end
  end
end

# Register the type
ActiveRecord::Type.register(:roaringbitmap64, ActiveRecord::Type::RoaringBitmap64)
```

***

### **Phase 3: Association Builder**

Create the core association builder following Rails' internal patterns.[1]

```ruby
# lib/active_record/associations/builder/has_many_bitmap.rb
module ActiveRecord::Associations::Builder
  class HasManyBitmap < CollectionAssociation
    
    def self.macro
      :has_many_bitmap
    end

    def self.valid_options(options)
      super + [:bitmap_column, :class_name, :foreign_key]
    end

    def self.define_readers(mixin, name)
      mixin.redefine_method(name) do |*args|
        association(name).reader(*args)
      end
    end

    def self.define_writers(mixin, name)
      mixin.redefine_method("#{name}=") do |value|
        association(name).writer(value)
      end
    end

    # Key method: Define methods for manipulating bitmap
    def self.define_extensions(model, name, &extension)
      model.generated_association_methods.module_eval do
        # Add an ID to the bitmap
        define_method "#{name.to_s.singularize}_ids_add" do |id|
          bitmap_column = association(name).reflection.options[:bitmap_column]
          current = read_attribute(bitmap_column) || []
          write_attribute(bitmap_column, (current + [id]).uniq)
        end

        # Remove an ID from the bitmap
        define_method "#{name.to_s.singularize}_ids_remove" do |id|
          bitmap_column = association(name).reflection.options[:bitmap_column]
          current = read_attribute(bitmap_column) || []
          write_attribute(bitmap_column, current - [id])
        end

        # Check if ID exists in bitmap
        define_method "#{name.to_s.singularize}_ids_include?" do |id|
          bitmap_column = association(name).reflection.options[:bitmap_column]
          ids = read_attribute(bitmap_column) || []
          ids.include?(id)
        end
      end
    end
  end
end
```

***

### **Phase 4: Association Class**

Implement the association logic that handles querying and manipulation.

```ruby
# lib/active_record/associations/has_many_bitmap_association.rb
module ActiveRecord
  module Associations
    class HasManyBitmapAssociation < CollectionAssociation
      
      # Load target records from bitmap
      def reader(force_reload = false)
        reload if force_reload || stale_target?
        @proxy ||= CollectionProxy.new(klass, self)
      end

      # Replace entire bitmap with new records
      def writer(records)
        replace(records)
      end

      # Add records to bitmap
      def concat(*records)
        records.flatten!
        raise_on_type_mismatch!(records)
        
        new_ids = records.map(&:id).compact
        current_ids = owner.read_attribute(bitmap_column) || []
        owner.write_attribute(bitmap_column, (current_ids + new_ids).uniq)
        
        records
      end
      alias_method :<<, :concat
      alias_method :push, :concat

      # Remove records from bitmap
      def delete(*records)
        remove_ids = records.flatten.map { |r| r.respond_to?(:id) ? r.id : r }
        current_ids = owner.read_attribute(bitmap_column) || []
        owner.write_attribute(bitmap_column, current_ids - remove_ids)
        
        records
      end

      # Replace entire association
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch!(val) }
        new_ids = other_array.map { |r| r.respond_to?(:id) ? r.id : r }
        owner.write_attribute(bitmap_column, new_ids)
      end

      # Check if bitmap contains any IDs
      def empty?
        ids = owner.read_attribute(bitmap_column) || []
        ids.empty?
      end

      # Count of IDs in bitmap
      def size
        ids = owner.read_attribute(bitmap_column) || []
        ids.size
      end

      private

      def bitmap_column
        reflection.options[:bitmap_column] || 
          "#{reflection.name.to_s.singularize}_ids"
      end

      # Load actual records from bitmap IDs
      def find_target
        ids = owner.read_attribute(bitmap_column) || []
        return [] if ids.empty?
        
        scope.where(klass.primary_key => ids).to_a
      end

      # Efficient existence check using PostgreSQL
      def include_in_memory?(record)
        ids = owner.read_attribute(bitmap_column) || []
        ids.include?(record.id)
      end
    end
  end
end
```

***

### **Phase 5: ClassMethods Extension**

Add the `has_many_bitmap` macro to ActiveRecord models.

```ruby
# lib/active_record/associations/bitmap_associations.rb
module ActiveRecord
  module Associations
    module BitmapAssociations
      def has_many_bitmap(name, scope = nil, **options, &extension)
        reflection = Builder::HasManyBitmap.build(
          self, 
          name, 
          scope, 
          options, 
          &extension
        )
        
        Reflection.add_reflection(self, name, reflection)
        reflection
      end
    end
  end
end

# Inject into ActiveRecord::Base
ActiveRecord::Base.extend(ActiveRecord::Associations::BitmapAssociations)
```

***

### **Phase 6: Arel Visitor Extension**

Handle roaringbitmap64 operations in SQL generation for advanced querying.

```ruby
# lib/arel/visitors/postgresql_roaringbitmap.rb
module Arel
  module Visitors
    class PostgreSQL
      # Add bitmap contains operator
      def visit_Arel_Nodes_RoaringBitmapContains(node, collector)
        infix_value(node, collector, '@>')
      end

      # Add bitmap intersection operator
      def visit_Arel_Nodes_RoaringBitmapIntersect(node, collector)
        infix_value(node, collector, '&')
      end

      # Add bitmap union operator
      def visit_Arel_Nodes_RoaringBitmapUnion(node, collector)
        infix_value(node, collector, '|')
      end
    end
  end
end
```

***

### **Phase 7: Query Interface Extensions**

Add convenient query methods for bitmap operations.

```ruby
# lib/active_record/querying_methods/roaring_bitmap.rb
module ActiveRecord
  module QueryMethods
    module RoaringBitmap64
      # Find records where bitmap column contains specific ID
      def where_bitmap_contains(column, id)
        where("#{column} @> ?", id)
      end

      # Find records where bitmap intersects with array
      def where_bitmap_intersects(column, ids)
        where("#{column} && roaringbitmap64(?)", "{#{ids.join(',')}}")
      end

      # Count intersection size efficiently
      def count_bitmap_intersection(column, ids)
        select("rb_and_cardinality(#{column}, roaringbitmap64(?)) as count", 
               "{#{ids.join(',')}}")
      end
    end
  end
end

ActiveRecord::Relation.include(ActiveRecord::QueryMethods::RoaringBitmap64)
```

***

### **Phase 8: Preloading Support**

Implement efficient eager loading for bitmap associations.

```ruby
# lib/active_record/associations/preloader/has_many_bitmap.rb
module ActiveRecord
  module Associations
    class Preloader
      class HasManyBitmap < Association
        def records_for(ids)
          # Collect all bitmap IDs from owners
          all_ids = owners.flat_map do |owner|
            owner.read_attribute(reflection.options[:bitmap_column]) || []
          end.uniq

          # Single query for all related records
          scope.where(klass.primary_key => all_ids).index_by(&:id)
        end

        def load_records
          # Load all records at once
          records_by_id = records_for(owner_keys)

          # Assign to each owner based on their bitmap
          owners.each do |owner|
            ids = owner.read_attribute(reflection.options[:bitmap_column]) || []
            associated_records = ids.map { |id| records_by_id[id] }.compact
            associate_records_to_owner(owner, associated_records)
          end
        end
      end
    end
  end
end
```

***

### **Phase 9: Usage Example**

```ruby
class User < ApplicationRecord
  # Define bitmap column to store post IDs
  attribute :viewed_post_ids, :roaringbitmap64

  # Define association
  has_many_bitmap :viewed_posts,
                  class_name: 'Post',
                  bitmap_column: :viewed_post_ids
end

# Usage
user = User.first
user.viewed_posts << Post.find(1)
user.viewed_post_ids_add(5)
user.viewed_posts.size # => 2
user.viewed_posts # => [#<Post id: 1>, #<Post id: 5>]

# Efficient queries
User.where_bitmap_contains(:viewed_post_ids, 42)
User.where_bitmap_intersects(:viewed_post_ids, [1, 2, 3])

# Preloading
User.includes(:viewed_posts).each do |user|
  user.viewed_posts # Already loaded, no N+1
end
```

***

### **Phase 10: Testing Strategy (RSpec)**

```ruby
# spec/lib/active_record/associations/has_many_bitmap_spec.rb
RSpec.describe 'HasManyBitmap Association' do
  describe 'basic operations' do
    it 'adds records to bitmap' do
      user = create(:user)
      post = create(:post)
      
      user.viewed_posts << post
      expect(user.viewed_post_ids).to include(post.id)
    end

    it 'removes records from bitmap' do
      user = create(:user)
      post = create(:post)
      user.viewed_posts << post
      
      user.viewed_posts.delete(post)
      expect(user.viewed_post_ids).not_to include(post.id)
    end
  end

  describe 'queries' do
    it 'finds users who viewed specific post' do
      post = create(:post)
      user1 = create(:user)
      user1.viewed_posts << post
      
      results = User.where_bitmap_contains(:viewed_post_ids, post.id)
      expect(results).to include(user1)
    end
  end
end
```

***

### **Key Implementation Considerations**

1. **Arel Integration**: You'll need to ensure Arel visitors properly handle roaringbitmap64 operators (`@>`, `&&`, `|`, `&`) for query generation

2. **Connection Adapter**: May need to extend `PostgreSQLAdapter` to register the roaringbitmap64 OID type properly

3. **Migration Helper**: Create a helper method like `t.roaring_bitmap :column_name` for schema definitions

4. **Validation**: Add validations to ensure IDs in bitmap actually exist in target table

5. **Callbacks**: Implement `after_save` to persist bitmap changes atomically

6. **Dirty Tracking**: Extend ActiveModel::Dirty to track bitmap column changes properly

***

### **Performance Benefits**

- **Storage**: Roaring bitmaps compress sparse ID sets efficiently (often 10-100x better than arrays)
- **Queries**: Set operations (`&`, `|`, `@>`) are SIMD-accelerated and extremely fast
- **Cardinality**: Counting is O(1) without loading records
- **Aggregation**: Can aggregate bitmaps across rows efficiently

This approach is particularly powerful for tracking user interactions, permissions, feature flags, or any scenario where you need efficient set membership testing across large ID spaces.

[1](http://callahan.io/blog/2014/10/08/behind-the-scenes-of-the-has-many-active-record-association)
[2](https://weblog.jamisbuck.org/2007/1/9/extending-activerecord-associations.html)
[3](https://www.postgresql.eu/events/pgconfeu2023/sessions/session/4762/slides/408/roaring.pdf)
[4](https://api.rubyonrails.org/v3.2/classes/ActiveRecord/Associations/ClassMethods.html)
[5](https://apidock.com/rails/ActiveRecord/Associations/ClassMethods)
[6](https://github.com/ChenHuajun/pg_roaringbitmap)
[7](https://railsdoc.github.io/classes/ActiveRecord/Associations/ClassMethods.html)
[8](https://tadas-s.github.io/ruby-on-rails/2020/02/15/extending-active-record-associations/)
[9](https://pgxn.org/dist/pg_roaringbitmap/)
[10](https://apidock.com/rails/ActiveRecord/Associations/ClassMethods/has_many)
[11](https://railsadventures.wordpress.com/2012/08/28/activerecord-association-extensions/)
[12](https://stackoverflow.com/questions/61430073/please-explain-the-has-many-through-source-rails-association)
[13](https://msp-greg.github.io/rails_master/ActiveRecord/Associations/HasManyThroughAssociation.html)
[14](https://guides.rubyonrails.org/association_basics.html)
[15](https://ashgaikwad.substack.com/p/implementing-has-many-through-association)
[16](https://api.rubyonrails.org/classes/ActiveRecord/Associations/ClassMethods.html)
[17](https://apidock.com/rails/v5.2.3/ActiveRecord/Associations/ClassMethods/has_and_belongs_to_many)
[18](https://guides.rubyonrails.org/v5.0/association_basics.html)