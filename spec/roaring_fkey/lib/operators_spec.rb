require 'spec_helper'

RSpec.describe 'operators', :aggregate_failures, :db  do
  before do
    Video.belongs_to_many(:tags)
    Tag.belongs_to_many(:comments)
  end

  context 'roaringbitmap64 in operators' do
    it 'max' do
      # query = Video.maximum(:tag_ids)
      # in query sql func max %{rb_max("videos"."tag_ids")}
      # expect(query.to_sql).to must_be_like(query_sql)
      expect { Video.maximum(:tag_ids) }.not_to raise_error
    end

    it 'min' do
      # query = Video.minimum(:tag_ids)
      # in query sql func min %{rb_min("videos"."tag_ids")}
      # expect(query.to_sql).to must_be_like(query_sql)
      expect { Video.minimum(:tag_ids) }.not_to raise_error
    end

    it 'count' do
      query = Video.where(id: 1).select("count(tag_ids)")
      # in query sql func count %{rb_cardinality("videos"."tag_ids")}
      expect { query.load }.not_to raise_error
    end
  end

  context 'roaringbitmap in operators' do
    it 'max' do
      expect { Tag.maximum(:comment_ids) }.not_to raise_error
    end

    it 'min' do
      expect { Tag.minimum(:comment_ids) }.not_to raise_error
    end

    it 'count' do
      query = Tag.where(id: 1).select("count(comment_ids)")
      expect { query.load }.not_to raise_error
    end
  end
end
