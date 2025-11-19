require 'spec_helper'

RSpec.describe 'Auto-Detect RoaringBitmap Type', :aggregate_failures, :db do
  let(:connection) { ActiveRecord::Base.connection }

  context 'when model has integer primary key' do
    before do
      connection.drop_table(:int_players) if connection.table_exists?(:int_players)
      connection.drop_table(:games) if connection.table_exists?(:games)

      connection.create_table(:int_players) { |t| t.string :name; t.primary_key :id, :integer }
      connection.create_table(:games) { |t| t.string :name; t.column :player_ids, :roaringbitmap }
    end

    after do
      connection.drop_table(:int_players) if connection.table_exists?(:int_players)
      connection.drop_table(:games) if connection.table_exists?(:games)
    end

    class IntPlayer < ActiveRecord::Base
      self.table_name = 'int_players'
    end

    class Game < ActiveRecord::Base
      self.table_name = 'games'
      belongs_to_many :players, anonymous_class: IntPlayer
    end

    it 'automatically uses roaringbitmap for integer IDs' do
      reflection = Game.reflect_on_association(:players)
      expect(reflection.roaringbitmap_type).to eq(:roaringbitmap)
      expect(reflection.roaringbitmap64?).to be_falsey
    end

    it 'creates games with integer player IDs' do
      players = 3.times.map { IntPlayer.create!(name: "Player #{_1}") }
      game = Game.create!(name: 'Test Game', players: players)
      
      expect(game.players.count).to eq(3)
      expect(game.player_ids).to match_array(players.map(&:id))
    end
  end

  context 'when model has bigint primary key' do
    before do
      connection.drop_table(:bigint_players) if connection.table_exists?(:bigint_players)
      connection.drop_table(:games) if connection.table_exists?(:games)

      connection.create_table(:bigint_players) { |t| t.string :name; t.primary_key :id, :bigint }
      connection.create_table(:games) { |t| t.string :name; t.column :player_ids, :roaringbitmap64 }
    end

    after do
      connection.drop_table(:bigint_players) if connection.table_exists?(:bigint_players)
      connection.drop_table(:games) if connection.table_exists?(:games)
    end

    class BigintPlayer < ActiveRecord::Base
      self.table_name = 'bigint_players'
    end

    class Game < ActiveRecord::Base
      self.table_name = 'games'
      belongs_to_many :players, anonymous_class: BigintPlayer
    end

    it 'automatically uses roaringbitmap64 for bigint IDs' do
      reflection = Game.reflect_on_association(:players)
      expect(reflection.roaringbitmap_type).to eq(:roaringbitmap64)
      expect(reflection.roaringbitmap64?).to be_truthy
    end

    it 'creates games with bigint player IDs' do
      players = 3.times.map { BigintPlayer.create!(name: "Player #{_1}") }
      game = Game.create!(name: 'Test Game', players: players)
      
      expect(game.players.count).to eq(3)
      expect(game.player_ids).to match_array(players.map(&:id))
    end
  end

  context 'when explicit type is specified' do
    before do
      connection.drop_table(:players) if connection.table_exists?(:players)
      connection.drop_table(:games) if connection.table_exists?(:games)

      connection.create_table(:players) { |t| t.string :name; t.primary_key :id, :bigint }
      connection.create_table(:games) { |t| t.string :name; t.column :player_ids, :roaringbitmap }
    end

    after do
      connection.drop_table(:players) if connection.table_exists?(:players)
      connection.drop_table(:games) if connection.table_exists?(:games)
    end

    class Player < ActiveRecord::Base
      self.table_name = 'players'
    end

    class Game < ActiveRecord::Base
      self.table_name = 'games'
      # Explicitly specify roaringbitmap despite bigint IDs
      belongs_to_many :players, anonymous_class: Player
    end

    it 'respects explicit type specification' do
      reflection = Game.reflect_on_association(:players)
      expect(reflection.roaringbitmap_type).to eq(:roaringbitmap)
      expect(reflection.roaringbitmap64?).to be_falsey
    end
  end

  context 'when using class_name instead of anonymous_class' do
    before do
      connection.drop_table(:players) if connection.table_exists?(:players)
      connection.drop_table(:games) if connection.table_exists?(:games)

      connection.create_table(:players) { |t| t.string :name; t.primary_key :id, :bigint }
      connection.create_table(:games) { |t| t.string :name; t.column :player_ids, :roaringbitmap64 }
    end

    after do
      connection.drop_table(:players) if connection.table_exists?(:players)
      connection.drop_table(:games) if connection.table_exists?(:games)
    end

    class Player < ActiveRecord::Base
      self.table_name = 'players'
    end

    class Game < ActiveRecord::Base
      self.table_name = 'games'
      # Using class_name instead of anonymous_class
      belongs_to_many :players, class_name: 'Player'
    end

    it 'detects type correctly with class_name' do
      reflection = Game.reflect_on_association(:players)
      expect(reflection.roaringbitmap_type).to eq(:roaringbitmap64)
      expect(reflection.roaringbitmap64?).to be_truthy
    end
  end

  context 'when custom foreign_key is specified' do
    before do
      connection.drop_table(:players) if connection.table_exists?(:players)
      connection.drop_table(:games) if connection.table_exists?(:games)

      connection.create_table(:players) { |t| t.string :name; t.primary_key :id, :bigint }
      connection.create_table(:games) { |t| t.string :name; t.column :participant_ids, :roaringbitmap64 }
    end

    after do
      connection.drop_table(:players) if connection.table_exists?(:players)
      connection.drop_table(:games) if connection.table_exists?(:games)
    end

    class Player < ActiveRecord::Base
      self.table_name = 'players'
    end

    class Game < ActiveRecord::Base
      self.table_name = 'games'
      # Using custom foreign_key
      belongs_to_many :participants, class_name: 'Player', foreign_key: :participant_ids
    end

    it 'detects type correctly with custom foreign_key' do
      reflection = Game.reflect_on_association(:participants)
      expect(reflection.roaringbitmap_type).to eq(:roaringbitmap64)
      expect(reflection.roaringbitmap64?).to be_truthy
    end
  end
end