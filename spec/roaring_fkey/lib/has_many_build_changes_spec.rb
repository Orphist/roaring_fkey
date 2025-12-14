# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'HasManyAssociation build_changes issue', :aggregate_failures, :db do
  # This test verifies that the undefined method `build_changes' error
  # does NOT occur when using standard has_many associations alongside
  # belongs_to_many associations.
  #
  # The issue (TODO item #0) was:
  # "Fix undefined method `build_changes' for #<ActiveRecord::Associations::HasManyAssociation"
  #
  # The build_changes method is only defined on BelongsToManyAssociation,
  # but the autosave callbacks were previously calling it on all associations.
  # The fix in autosave_association.rb adds a respond_to? guard.

  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.drop_table(:children) if connection.table_exists?(:children)
    connection.drop_table(:parents) if connection.table_exists?(:parents)
    connection.drop_table(:related_items) if connection.table_exists?(:related_items)

    connection.create_table(:children) { |t| t.string :name; t.references :parent }
    connection.create_table(:parents) { |t| t.string :name; t.column :related_item_ids, :roaringbitmap }
    connection.create_table(:related_items) { |t| t.string :name }
    connection.schema_cache.clear!
  end

  after do
    connection.drop_table(:children) if connection.table_exists?(:children)
    connection.drop_table(:parents) if connection.table_exists?(:parents)
    connection.drop_table(:related_items) if connection.table_exists?(:related_items)
  end

  # Model with both has_many and belongs_to_many associations
  class RelatedItem < ActiveRecord::Base
    self.table_name = 'related_items'
  end

  class Child < ActiveRecord::Base
    self.table_name = 'children'
    belongs_to :parent
  end

  class Parent < ActiveRecord::Base
    self.table_name = 'parents'

    # Standard has_many association - uses HasManyAssociation which does NOT have build_changes
    has_many :children

    # Roaring bitmap association - uses BelongsToManyAssociation which HAS build_changes
    options = { anonymous_class: RelatedItem, foreign_key: :related_item_ids }
    options[:inverse_of] = false
    belongs_to_many :related_items, **options
  end

  describe 'HasManyAssociation without build_changes' do
    it 'does not have build_changes method' do
      parent = Parent.new(name: 'Test Parent')
      association = parent.association(:children)
      
      # Verify that HasManyAssociation does NOT have build_changes
      expect(association).not_to respond_to(:build_changes)
      expect(association.class).to eq(ActiveRecord::Associations::HasManyAssociation)
    end
  end

  describe 'BelongsToManyAssociation with build_changes' do
    it 'has build_changes method' do
      parent = Parent.new(name: 'Test Parent')
      association = parent.association(:related_items)
      
      # Verify that BelongsToManyAssociation HAS build_changes
      expect(association).to respond_to(:build_changes)
      expect(association.class).to eq(RoaringFkey::PostgreSQL::Associations::BelongsToManyAssociation)
    end
  end

  describe 'saving parent with both association types' do
    context 'when parent has nested children via has_many' do
      it 'does not raise undefined method build_changes error' do
        # This test would fail before the respond_to? guard was added in
        # autosave_association.rb::save_belongs_to_many_association
        parent = Parent.new(name: 'Test Parent')
        child = Child.new(name: 'Test Child')
        
        parent.children << child
        
        # This should not raise NoMethodError for build_changes
        expect { parent.save! }.not_to raise_error
        expect(parent.reload.children.count).to eq(1)
      end
    end

    context 'when parent has belongs_to_many items' do
      it 'correctly saves the association using build_changes' do
        related = RelatedItem.create!(name: 'Related 1')
        parent = Parent.new(name: 'Test Parent')
        
        parent.related_items << related
        
        expect { parent.save! }.not_to raise_error
        expect(parent.reload.related_items.count).to eq(1)
      end
    end

    context 'when parent has both has_many children and belongs_to_many items' do
      it 'correctly saves both associations without build_changes error' do
        related = RelatedItem.create!(name: 'Related 1')
        parent = Parent.new(name: 'Test Parent')
        child = Child.new(name: 'Test Child')
        
        parent.children << child
        parent.related_items << related
        
        # This is the critical test - saving a parent with both association types
        # should not trigger "undefined method `build_changes'" error
        expect { parent.save! }.not_to raise_error
        
        parent.reload
        expect(parent.children.count).to eq(1)
        expect(parent.related_items.count).to eq(1)
      end
    end

    context 'when updating parent with both associations' do
      it 'correctly updates without build_changes error' do
        # Create initial data
        related1 = RelatedItem.create!(name: 'Related 1')
        parent = Parent.create!(name: 'Test Parent')
        child1 = Child.create!(name: 'Child 1', parent: parent)
        parent.related_items << related1
        parent.save!
        
        # Update with new associations
        related2 = RelatedItem.create!(name: 'Related 2')
        child2 = Child.new(name: 'Child 2')
        
        parent.children << child2
        parent.related_items << related2
        parent.name = 'Updated Parent'
        
        expect { parent.save! }.not_to raise_error
        
        parent.reload
        expect(parent.name).to eq('Updated Parent')
        expect(parent.children.count).to eq(2)
        expect(parent.related_items.count).to eq(2)
      end
    end
  end

  describe 'directly calling build_changes on HasManyAssociation' do
    it 'raises NoMethodError when build_changes is called directly' do
      parent = Parent.new(name: 'Test Parent')
      association = parent.association(:children)
      
      # This demonstrates the actual error that would occur without the guard
      expect(association).not_to respond_to(:build_changes)
      expect { association.build_changes { 'test' } }.to raise_error(NoMethodError, /undefined method.*build_changes/)
    end
  end
end
