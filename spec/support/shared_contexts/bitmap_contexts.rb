RSpec.shared_context "bitmap Video model" do
  ActiveRecord::Base.connection.create_table(:videos, force: true) do |t|
    t.text :title
  end

  class Video < ActiveRecord::Base
  end
end

RSpec.shared_context "bitmap Playlist model" do
  ActiveRecord::Base.connection.create_table(:playlists, force: true) do |t|
    t.column :video_ids, :roaringbitmap
  end

  class Playlist < ActiveRecord::Base
    has_bitmap_of :videos
    attribute :video_ids, :roaringbitmap

    after_commit :reloadme

    def reloadme
      # binding.pry
      # reload
    end
  end
end

RSpec.shared_context "bitmap Video model belonging to Playlist" do
  ActiveRecord::Base.connection.create_table(:videos, force: true) do |t|
    t.text :title
  end

  class Video < ActiveRecord::Base
    has_many :playlists, foreign_key: :video_ids
  end
end

RSpec.shared_context "bitmap Players in Games" do
  connection = ActiveRecord::Base.connection
  connection.create_table(:players, force: true) do |t|
    t.text :name
  end
  connection.create_table(:games, force: true) do |t|
    t.text :name
    t.roaringbitmap64 :player_ids
  end

  class Player < ActiveRecord::Base
    self.table_name = 'players'

    has_many :playlists, foreign_key: :video_ids
  end

  class Game < ActiveRecord::Base
    self.table_name = 'games'

    options = { anonymous_class: Player, foreign_key: :player_ids }
    options[:inverse_of] = false # if RoaringFkey::PostgreSQL::AR610
    belongs_to_many :players, **options
  end
end



RSpec.shared_context "bitmap TV series" do
  let!(:return_of_harmony) {
    Video.create(title: "My Little Pony s02e01 'The Return of Harmony'") # id=1
  }
  let!(:something_big) {
    Video.create(title: "Adventure Time s06e10 'Something Big'") # id=2
  }
  let!(:escape_from_the_citadel) {
    Video.create(title: "Adventure Time s06e02 'Escape from the Citadel'")
  }
  let!(:food_chain) {
    Video.create(title: "Adventure Time s06e07 'Food Chain'")
  }

  let!(:adventure_time_videos) { [something_big, escape_from_the_citadel] }
  let!(:adventure_time_season6) {
    begin
      playlist=Playlist.new(video_ids: adventure_time_videos.map(&:id))
      playlist.save!
      playlist
    rescue =>e
      p e
      p caller
    end
  }

  let!(:mlp_videos) { [return_of_harmony] }
  let!(:mlp_season2) {
    Playlist.create(video_ids: mlp_videos.map(&:id))
  }

  let!(:my_cool_videos) {
    [return_of_harmony, something_big]
  }
  let!(:my_cool_video_ids) { my_cool_videos.map(&:id) }
  let!(:my_cool_list) {
    Playlist.create(video_ids: my_cool_video_ids.dup)
  }
end
