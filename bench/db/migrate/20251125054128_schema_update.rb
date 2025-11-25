class SchemaUpdate < ActiveRecord::Migration[6.1]
  def up
    remove_column :roaring_fkey_authors, :book_ids if column_exists?(:roaring_fkey_authors, :book_ids)
    add_column :roaring_fkey_authors, :book_ids, :roaringbitmap64

    remove_column :roaring_fkey_suppliers, :book_ids if column_exists?(:roaring_fkey_suppliers, :book_ids)
    add_column :roaring_fkey_suppliers, :book_ids, :roaringbitmap64

    remove_column :roaring_fkey_books, :review_ids if column_exists?(:roaring_fkey_books, :review_ids)
    add_column :roaring_fkey_books, :review_ids, :roaringbitmap64
    
    remove_column :roaring_fkey_books, :order_ids if column_exists?(:roaring_fkey_books, :order_ids)
    add_column :roaring_fkey_books, :order_ids, :roaringbitmap64

    remove_column :roaring_fkey_customers, :review_ids if column_exists?(:roaring_fkey_customers, :review_ids)
    add_column :roaring_fkey_customers, :review_ids, :roaringbitmap64
    
    remove_column :roaring_fkey_customers, :order_ids if column_exists?(:roaring_fkey_customers, :order_ids)
    add_column :roaring_fkey_customers, :order_ids, :roaringbitmap64

    remove_column :roaring_fkey_orders, :book_ids if column_exists?(:roaring_fkey_orders, :book_ids)
    add_column :roaring_fkey_orders, :book_ids, :roaringbitmap64
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end