require 'spec_helper'

RSpec.describe 'BelongsToMany', :aggregate_failures, :db  do
  context 'on model' do
    let(:model) { Video }
    let(:builder) { RoaringFkey::PostgreSQL::Associations::Builder::BelongsToMany }
    let(:reflection) { RoaringFkey::PostgreSQL::Reflection::BelongsToManyReflection }
    after { model._reflections = {} }

    it 'has the builder method' do
      expect(model).to respond_to(:belongs_to_many)
    end

    it 'triggers the correct builder and relation' do
      expect(builder).to receive(:build).with(anything, :tests, nil, {}) do |_, name, _, _|
        ActiveRecord::Reflection.create(:belongs_to_many, name, nil, {}, model)
      end

      expect(reflection).to receive(:new).with(:tests, nil, {}, model)

      model.belongs_to_many(:tests)
    end
  end

  context 'roaringbitmap in joins' do
    before do
      Video.belongs_to_many(:tags)
      Tag.belongs_to_many(:comments)
    end

    it 'can joins records' do
      query = Video.all.joins(:tags)
      query_sql = %{INNER JOIN "tags" ON ("videos"."tag_ids" @> "tags"."id"::int AND NOT (rb_is_empty("videos"."tag_ids")))}
      expect(query.to_sql).to must_be_like(query_sql)
      expect { query.load }.not_to raise_error
    end

    it 'can joins reference' do
      query = Video.includes(tags: :comments).references(:tags).where("tags.id is not null")
      query_sql = %{LEFT OUTER JOIN "tags" ON ("videos"."tag_ids" @> "tags"."id"::int AND NOT (rb_is_empty("videos"."tag_ids")))}
      expect(query.to_sql).to must_be_like(query_sql)
      query_sql = %{LEFT OUTER JOIN "comments" ON ("tags"."comment_ids" @> "comments"."id"::int AND NOT (rb_is_empty("tags"."comment_ids")))}
      expect(query.to_sql).to must_be_like(query_sql)
      expect { query.load }.not_to raise_error
    end

    it 'can 2 joins' do
      query = Video.joins(tags: :comments).where("tags.id is not null").select('comments.*')
      query_sql = %{INNER JOIN "tags" ON ("videos"."tag_ids" @> "tags"."id"::int AND NOT (rb_is_empty("videos"."tag_ids")))}
      expect(query.to_sql).to must_be_like(query_sql)
      query_sql = %{INNER JOIN "comments" ON ("tags"."comment_ids" @> "comments"."id"::int AND NOT (rb_is_empty("tags"."comment_ids")))}
      expect(query.to_sql).to must_be_like(query_sql)
      expect { query.load }.not_to raise_error
    end

    it 'can left join' do
      query = Video.left_outer_joins(:tags)
      query_sql = %{LEFT OUTER JOIN "tags" ON ("videos"."tag_ids" @> "tags"."id"::int AND NOT (rb_is_empty("videos"."tag_ids")))}
      expect(query.to_sql).to must_be_like(query_sql)
    end
    
    it 'merge w/join && query counting' do
      relation = Video.all.merge!(select: "distinct videos.*",
                         includes: [tags: :comments],
                         references: :tags,
                         where: "1=1", order: "videos.id")
      query_count_eq(2) do
        relation.to_a
      end
      query_sql = %{LEFT OUTER JOIN "tags" ON ("videos"."tag_ids" @> "tags"."id"::int AND NOT (rb_is_empty("videos"."tag_ids")))}
      expect(relation.to_sql).to must_be_like(query_sql)
    end
  end

  context 'roaringbitmap on association video.tag_ids' do
    let(:other) { Tag }
    let(:initial) { FactoryBot.create(:tag) }

    before { Video.belongs_to_many(:tags) }
    subject { Video.create(title: 'A') }

    after do
      Video.reset_callbacks(:save)
      Video._reflections = {}
    end

    it 'can reload records' do
      expect(subject.tags.size).to be_eql(0)
      new_tag = FactoryBot.create(:tag)
      subject.tags << new_tag
      subject.tags.reload
      expect(subject.tags.size).to be_eql(1)

      new_tag2 = FactoryBot.create(:tag)
      subject.tags = [new_tag, new_tag2]
      subject.tags.reload

      expect(subject.tags.size).to be_eql(2)

      expect(subject.tags.first.id).to be_eql(new_tag.id)

      record = Video.create(title: 'B', tags: [new_tag])
      record.reload

      expect(record.tags.size).to be_eql(1)
      expect(record.tags.first.id).to be_eql(new_tag.id)
      expect(record.tag_ids).to be_eql([new_tag.id])

      new_tags = FactoryBot.create_list(:tag, 3)
      subject.tags = new_tags
      expect(subject.tags.size).to be_eql(3)

      expect(subject.tags.map(&:id)).to match_array(new_tags.map(&:id))
    end

    it 'has the method' do
      expect(subject).to respond_to(:tags)
      expect(subject._reflections).to include('tags')
    end

    it 'has correct foreign key' do
      item = subject._reflections['tags']
      expect(item.foreign_key).to be_eql('tag_ids')
    end

    it 'loads associated records' do
      subject.update(tag_ids: [initial.id])
      expect(subject.tags.to_sql).to be_eql <<-SQL.squish
        SELECT "tags".* FROM "tags" WHERE "tags"."id" IN (#{initial.id})
      SQL

      expect(subject.tags.load).to be_a(ActiveRecord::Associations::CollectionProxy)
      expect(subject.tags.to_a).to be_eql([initial])
    end

    it 'can be marked as loaded' do
      expect(subject.tags.loaded?).to be_eql(false)
      expect(subject.tags).to respond_to(:load_target)
      expect(subject.tags.load_target).to be_eql([])
      expect(subject.tags.loaded?).to be_eql(true)
    end

    it 'can find specific records' do
      records = FactoryBot.create_list(:tag, 10)
      subject.update(tag_ids: records.map(&:id))
      ids = records.map(&:id).sample(5)

      expect(subject.tags).to respond_to(:find)
      records = subject.tags.find(*ids)

      expect(records.size).to be_eql(5)
      expect(records.map(&:id).sort).to be_eql(ids.sort)
    end

    it 'can return last n records' do
      records = FactoryBot.create_list(:tag, 10)
      subject.update(tag_ids: records.map(&:id))
      ids = records.map(&:id).last(5)

      expect(subject.tags).to respond_to(:last)
      records = subject.tags.last(5)

      expect(records.size).to be_eql(5)
      expect(records.map(&:id).sort).to be_eql(ids.sort)
    end

    it 'can return first n records' do
      records = FactoryBot.create_list(:tag, 10)
      subject.update(tag_ids: records.map(&:id))
      ids = records.map(&:id).first(5)

      expect(subject.tags).to respond_to(:take)
      records = subject.tags.take(5)

      expect(records.size).to be_eql(5)
      expect(records.map(&:id).sort).to be_eql(ids.sort)
    end

    it 'can create the owner record with direct set items' do
      # Having another association would break this test due to how
      # +@new_record_before_save+ is set on autosave association
      Video.has_many(:comments)

      record = Video.create(title: 'A', tags: [initial])
      record.reload

      expect(record.tags.size).to be_eql(1)
      expect(record.tags.first.id).to be_eql(initial.id)
    end

    it 'can keep record changes accordingly' do
      expect(subject.tags.count).to be_eql(0)

      local_previous_changes = nil
      local_saved_changes = nil

      Video.after_commit do
        local_previous_changes = self.previous_changes.dup
        local_saved_changes = self.saved_changes.dup
      end

      subject.update(title: 'B')

      # expect(local_previous_changes).to include('title')
      # expect(local_saved_changes).to include('title')

      subject.tags = FactoryBot.create_list(:tag, 5)
      subject.update(title: 'C', url: 'X')
      subject.reload

      expect(local_previous_changes).to include('title', 'url')
      expect(local_saved_changes).to include('title', 'url')
      expect(local_previous_changes).not_to include('tag_ids')
      expect(local_saved_changes).not_to include('tag_ids')
      expect(subject.tag_ids.size).to be_eql(5)
      expect(subject.tags.count).to be_eql(5)
    end

    it 'can assign the record ids during before callback' do
      Video.before_save { self.tags = FactoryBot.create_list(:tag, 5) }

      record = Video.create(title: 'A')

      expect(Tag.count).to be_eql(5)
      expect(record.tag_ids.size).to be_eql(5)
      expect(record.tags.count).to be_eql(5)
    end

    it 'does not trigger after commit on the associated record' do
      called = false

      tag = FactoryBot.create(:tag)
      Tag.after_commit { called = true }

      expect(called).to be_falsey

      subject.tags << tag

      expect(subject.tag_ids).to be_eql([tag.id])
      expect(called).to be_falsey

      Tag.reset_callbacks(:commit)
    end

    it 'can build an associated record' do
      record = subject.tags.build(name: 'Test')
      expect(record).to be_a(other)
      expect(record).not_to be_persisted
      expect(record.name).to be_eql('Test')
      expect(subject.tags.target).to be_eql([record])

      expect(subject.save && subject.reload).to be_truthy
      expect(subject.tag_ids).to be_eql([record.id])
      expect(subject.tags.size).to be_eql(1)
    end

    it 'can create an associated record' do
      record = subject.tags.create(name: 'Test')
      expect(subject.tags).to respond_to(:create!)

      expect(record).to be_a(other)
      expect(record).to be_persisted
      expect(record.name).to be_eql('Test')
      expect(subject.tag_ids).to be_eql([record.id])
    end

    it 'can concat records' do
      record = FactoryBot.create(:tag)
      subject.update(tag_ids: [record.id])
      expect(subject.tags.size).to be_eql(1)

      subject.tags.concat(other.new(name: 'Test'))
      subject.reload

      expect(subject.tags.size).to be_eql(2)
      expect(subject.tag_ids.size).to be_eql(2)
      expect(subject.tags.last.name).to be_eql('Test')
    end

    it 'can replace records' do
      subject.tags << FactoryBot.create(:tag)
      expect(subject.tags.size).to be_eql(1)

      subject.tags = [other.new(name: 'Test 1')]
      subject.reload

      expect(subject.tags.size).to be_eql(1)
      expect(subject.tags[0].name).to be_eql('Test 1')

      subject.tags.replace([other.new(name: 'Test 2'), other.new(name: 'Test 3')])
      subject.reload

      expect(subject.tags.size).to be_eql(2)
      expect(subject.tags[0].name).to be_eql('Test 2')
      expect(subject.tags[1].name).to be_eql('Test 3')
    end

    it 'can delete specific records' do
      subject.tags << initial
      expect(subject.tags.size).to be_eql(1)

      subject.tags.delete(initial)
      expect(subject.tags.size).to be_eql(0)
      expect(subject.reload.tags.size).to be_eql(0)
    end

    it 'can delete all records' do
      subject.tags.concat(FactoryBot.create_list(:tag, 5))
      expect(subject.tags.size).to be_eql(5)

      subject.tags.delete_all
      expect(subject.tags.size).to be_eql(0)
    end

    it 'can destroy all records' do
      subject.tags.concat(FactoryBot.create_list(:tag, 5))
      expect(subject.tags.size).to be_eql(5)

      subject.tags.destroy_all
      expect(subject.tags.size).to be_eql(0)
    end

    it 'can clear the array' do
      record = Video.create(title: 'B', tags: [initial])
      expect(record.tags.size).to be_eql(1)

      record.update(tag_ids: [])
      record.reload

      expect(record.tag_ids).to be_empty
      expect(record.tags.size).to be_eql(0)
    end

    it 'can have sum operations' do
      records = FactoryBot.create_list(:tag, 5)
      subject.tags.concat(records)

      result = records.map(&:id).reduce(:+)
      expect(subject.tags).to respond_to(:sum)
      expect(subject.tags.sum(:id)).to be_eql(result)
    end

    it 'can have a pluck operation' do
      records = FactoryBot.create_list(:tag, 5)
      subject.tags.concat(records)

      result = records.map(&:name).sort
      expect(subject.tags).to respond_to(:pluck)
      expect(subject.tags.pluck(:name).sort).to be_eql(result)
    end

    it 'can be markes as empty' do
      expect(subject.tags).to respond_to(:empty?)
      expect(subject.tags.empty?).to be_truthy

      subject.tags << FactoryBot.create(:tag)
      expect(subject.tags.empty?).to be_falsey
    end

    it 'can check if a record is included on the list' do
      outside = FactoryBot.create(:tag)
      inside = FactoryBot.create(:tag)

      expect(subject.tags).not_to be_include(inside)
      expect(subject.tags).not_to be_include(outside)

      subject.tags << inside

      expect(subject.tags).to respond_to(:include?)
      expect(subject.tags).to be_include(inside)
      expect(subject.tags).not_to be_include(outside)
    end

    it 'can append records' do
      subject.tags << other.new(name: 'Test 1')
      expect(subject.tags.size).to be_eql(1)

      subject.tags << other.new(name: 'Test 2')
      subject.update(title: 'B')
      subject.reload

      expect(subject.tags.size).to be_eql(2)
      expect(subject.tags.last.name).to be_eql('Test 2')
    end

    it 'can clear records' do
      subject.tags << FactoryBot.create(:tag)
      expect(subject.tags.size).to be_eql(1)

      subject.tags.clear
      expect(subject.tags.size).to be_eql(0)
    end

    it 'can reload records' do
      expect(subject.tags.size).to be_eql(0)
      new_tag = FactoryBot.create(:tag)
      subject.tags << new_tag

      subject.tags.reload
      expect(subject.tags.size).to be_eql(1)
      expect(subject.tags.first.id).to be_eql(new_tag.id)

      record = Video.create(title: 'B', tags: [new_tag])
      record.reload

      expect(record.tags.size).to be_eql(1)
      expect(record.tags.first.id).to be_eql(new_tag.id)
    end

    it 'can preload records' do
      records = FactoryBot.create_list(:tag, 5)
      subject.tags.concat(records)

      entries = Video.all.includes(:tags).load

      expect(entries.size).to be_eql(1)
      expect(entries.first.tags).to be_loaded
      expect(entries.first.tags.size).to be_eql(5)
    end

    it 'can preload records using ActiveRecord::Associations::Preloader' do
      records = FactoryBot.create_list(:tag, 5)
      subject.tags.concat(records)

      entries = Video.all
      ActiveRecord::Associations::Preloader.new.preload(entries, :tags, Tag.all)
      entries = entries.load

      expect(entries.size).to be_eql(1)
      expect(entries.first.tags).to be_loaded
      expect(entries.first.tags.size).to be_eql(5)
    end

    it 'can joins records' do
      query = Video.all.joins(:tags)
      expect(query.to_sql).to match(/INNER JOIN "tags"/)
      expect { query.load }.not_to raise_error
    end

    context 'When the attribute has a default value' do
      subject { FactoryBot.create(:item) }

      it 'will always return the column default value' do
        expect(subject.tag_ids).to be_a(Array)
        expect(subject.tag_ids).to be_eql([1])
      end

      it 'will keep the value as an array even when the association is cleared' do
        records = FactoryBot.create_list(:tag, 5)
        subject.tags.concat(records)

        subject.reload
        expect(subject.tag_ids).to be_a(Array)
        expect(subject.tag_ids).not_to be_eql([1, *records.map(&:id)])

        subject.tags.clear
        subject.reload
        expect(subject.tag_ids).to be_a(Array)
        expect(subject.tag_ids).to be_eql([1])
      end
    end

    context 'When record is not persisted' do
      let(:initial) { FactoryBot.create(:tag) }

      subject { Video.new(title: 'A', tags: [initial]) }

      it 'loads associated records' do
        expect(subject.tags.load).to be_a(ActiveRecord::Associations::CollectionProxy)
        expect(subject.tags.to_a).to be_eql([initial])
      end
    end
  end

  context 'using roaringbitmap' do
    let(:connection) { ActiveRecord::Base.connection }
    let(:other) { player.create }

    class Player < ActiveRecord::Base
      self.table_name = 'players'
    end

    class Game < ActiveRecord::Base
      self.table_name = 'games'

      options = { anonymous_class: Player, foreign_key: :player_ids }
      options[:inverse_of] = false# if RoaringFkey::PostgreSQL::AR610
      belongs_to_many :players, **options
    end

    # TODO: Set as a shared example
    before do
      connection.drop_table(:players) if connection.table_exists?(:players)
      connection.drop_table(:games) if connection.table_exists?(:games)

      connection.create_table(:players) { |t| t.string :name }
      connection.create_table(:games) { |t| t.string :name; t.column :player_ids, :roaringbitmap } #, default: 'x3a3000000100000000000000100000000000' }
    end

    let!(:games) { 5.times.map { Game.create } }
    let!(:players) { 5.times.map { Player.create(name: %w[Ace Bobby Leonard Doozer].sample) } }

    it 'can Game.first.players =' do
      game = Game.first
      game.players = players[0..1]
      game.save!
      expect(Game.find(games[0].id).players.first).to be_eql(players[0])
      # Game.find(games[0].id)
    end

    # player_ids << [1,3] FAIL
    it 'can Game.first.player_ids << ' do
      game = Game.second
      # Tracer.on
      game.player_ids << players[2..3].map(&:id)
      # Tracer.on
      # Tracer.add_filter do |event, file, line, id, binding, klass, *rest|
      #   #!%r[rubies|gems].match?(file)
      #   %r[roaring-pg|roaringbitmap].match?(file)
      # end
      expect(game.players).to eq(players[2..3])
      game.save!
      # Tracer.off
      # game.update!(player_ids: players[2..3].map(&:id), name: 'new name')
      # game.save!
      # Tracer.off
      # binding.pry
      expect(game.reload.players.last).to be_eql(players[3])
    end

    it 'can Game.find(games[1].id).players << ' do
      # binding.pry
      game = Game.find(games[1].id)
      game.players << players[0..1]
      game.save!
      expect(game.reload.players.last).to be_eql(players[1])
    end

    it 'can Game.find(games[2].id).players << ' do
      # expect(subject.tags.first.id).to be_eql(new_tag.id)
      game = Game.find(games[1].id)
      game.players << players[-2]
      game.save!
      expect(Game.find(games[1].id).players.first).to be_eql(players[-2])
    end

    it 'can game = Game.second;game.players = players[2..3] ' do
      game = Game.second
      game.players = players[2..3]
      game.save!
      # expect(game.players.first).to be_eql(players[2]) #=>fail FROM "players" WHERE "players"."id" IN ('{3,4}')
      expect(game.reload.players.first).to be_eql(players[2])
    end

    it 'can game = Game.second;game.player_ids = players[2..3].map(&:id)' do
      game = Game.second
      game.player_ids = players[2..3].map(&:id)
      game.save!
      # expect(game.players.first).to be_eql(players[2]) #=>fail FROM "players" WHERE "players"."id" IN ('{3,4}')
      expect(game.reload.players.first).to be_eql(players[2])
      expect(game.reload.players.count).to eq(2)
    end

    it 'can game = Game.create(player_ids = players[2..3].map(&:id))' do
      game = Game.create!(player_ids: players[2..3].map(&:id))
      # expect(game.players.first).to be_eql(players[2]) #=>fail FROM "players" WHERE "players"."id" IN ('{3,4}')
      expect(game.reload.players.first).to be_eql(players[2])
      expect(game.reload.players.count).to eq(2)
    end

    it 'where(player_ids:[2,4]) && where(player_ids:2)- ret game' do
      # Tracer.on
      ids = players[2..3].map(&:id)
      game = Game.create(player_ids: ids)
      expect(Game.where(player_ids: players[2].id).take).to eq(game)
      expect(Game.where(player_ids: [players[2].id]).take).to eq(game)
      expect(Game.where(player_ids: ids).take).to eq(game)
      # Tracer.off
    end

    it 'Game.find_by(player_ids:[2,4]) - ret game' do
      game = Game.create(player_ids: players[2..3].map(&:id))
      expect(Game.find_by(player_ids: [players[2].id])).to eq(game)
    end

    it 'where.not(player_ids:[2,4]) can game = Game.find_by(player_ids: players[2..3].map(&:id))' do
      game1 = Game.create(player_ids: [players[1].id])
      game2 = Game.create(player_ids: players[2..3].map(&:id))
      expect(Game.where(player_ids: players[2].id).take).to eq(game2)
      expect(Game.find_by(player_ids: [players[2].id])).to eq(game2)
      # Tracer.on
      expect(Game.where.not(player_ids: players[2].id).take).to eq(game1)
      # Tracer.off
    end

    it 'where(player_ids:[2,4]) can game = Game.find_by(player_ids: players[2..3].map(&:id))', :sql do
      game = Game.create(player_ids: players[2..3].map(&:id))
      sql = Game.where(player_ids: players[2].id).to_sql
      expect(sql).to must_be_like(%{"games"."player_ids" @> #{players[2].id}})
      sql = Game.where(player_ids: players[2..2].map(&:id)).to_sql
      expect(sql).to match(/"games"."player_ids" @> #{players[2].id}/i)
      sql = Game.where(player_ids: [3]).to_sql
      expect(sql).to match(/"games"."player_ids" @> 3/i)
      sql = Game.where.not(player_ids: players[2].id).to_sql
      expect(sql).to must_be_like(%{NOT("games"."player_ids" @> #{players[2].id})})
    end

    it 'None where.not(player_ids: {some empty conditions})', :sql do
      sql = Game.where.not(player_ids: Player.none).to_sql
      expect(sql).to must_be_like(%{NOT rb_is_empty("games"."player_ids")})
      sql = Game.where.not(player_ids: nil).to_sql
      expect(sql).to must_be_like(%{NOT rb_is_empty("games"."player_ids")})
      sql = Game.where.not(player_ids: []).to_sql
      expect(sql).to must_be_like(%{NOT rb_is_empty("games"."player_ids")})
    end

    it 'None where(player_ids:[])', :sql do
      sql = Game.where(player_ids: []).to_sql
      expect(sql).to must_be_like(%{rb_is_empty("games"."player_ids")})
    end

    it 'can Game.find(games[2].id).players << ' do
      game = Game.first
      game.players << players[-1]
      game.save!
      expect(game.reload.players.first).to be_eql(players[-1])
      expect(game.reload.players.count).to be_eql(1)
    end

    # FixMe: player_ids << [1,4] FAIL
    # But: if
    #   game.player_ids << [3,4]
    #   game.players
    #   game.save!
    #   OK - when save players
    xit 'can join Game.where(id: games[1..2]).player_ids << players[-1]' do
      game = Game.second
      game.player_ids << players[2..3].map(&:id)
      game.save!
      expect(game.reload.players.last).to be_eql(players[3])
    end

    # ToDo: fix the previous_changes && saved_changes - its active model support - .changed etc
    xit 'can assocs have previous_changes && saved_changes' do
      game = Game.new
      game.name = 'Hello'
      player = Player.new
      game.players = [player]
      player.name = 'foo'
      
      # 1 when neither game nor player are yet persisted and they have new
      # info, game.save updates both and previous_changes exist for both
      game.save
      expect(game.previous_changes.any?).to be false
      expect(game.players.count).to eq 1
      expect(game.players.first.previous_changes.any?).to be_present #????

      # 2 when you save game with no changes previous_changes becomes empty
      game.save
      expect(game.previous_changes.any?).to be false # previous_changed == {}
      expect(game.players.first.previous_changes.any?).to be false #???? these are the same previous changes as before
      
      # 3 when game and player both have new information and you save 
      # game only game is updated therefore the previous_changes the player had in step one are still there
      game.name = 'Hello 2'
      player.name = 'bar'
      expect(game.changed?).to be true
      expect(game.changed).to eq ['name']
      expect(game.changes).to eq("name"=>['Hello', 'Hello 2'])
      game.name_changed?(from: 'Hello', to: 'Hello 2') # => true
      game.save
      expect(game.previous_changes.any?).to be_present
      expect(game.players.first.previous_changes["name"]).to be_blank # player didn't get updated
    end

    it 'can join Game.where(id: games[1..2]).player_ids << players[-1]' do
      game = Game.second
      game.player_ids << players[2..3].map(&:id)
      expect(game.players).to eq(players[2..3])
      game.save!
      expect(game.players).to eq(players[2..3])
      expect(game.reload.players.last).to eq(players[3])
    end

    it "should construct new finder sql after create" do
      game = Game.new
      expect(game.players.to_a).to(eq([]))
      player = Player.create!(name: "clark-sydney")
      game.players << player
      game.save!
      expect(game.players.find(player.id)).to eq(player)
    end
  end

  context 'ar_spec roaringbitmap' do
    let(:connection) { ActiveRecord::Base.connection }

    class Electron < ActiveRecord::Base
      self.table_name = :electrons

      belongs_to :molecule

      validates_presence_of :name
    end

    class Molecule < ActiveRecord::Base
      self.table_name = :molecules

      belongs_to :liquid

      options = { anonymous_class: Electron, foreign_key: :electron_ids }
      options[:inverse_of] = false if RoaringFkey::PostgreSQL::AR610
      belongs_to_many :electrons, **options
      # attribute :electron_ids, ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap.new
      # accepts_nested_attributes_for :electrons
    end

    class Liquid < ActiveRecord::Base
      self.table_name = :liquid

      has_many :molecules, -> { distinct }
      options = { anonymous_class: Molecule, foreign_key: :molecule_ids }
      options[:inverse_of] = false if RoaringFkey::PostgreSQL::AR610
      belongs_to_many :molecules, **options
      # attribute :molecule_ids, ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Roaringbitmap.new
      # accepts_nested_attributes_for :molecules
    end

    before do
      connection.drop_table(:electrons) if connection.table_exists?(:electrons)
      connection.drop_table(:molecules) if connection.table_exists?(:molecules)
      connection.drop_table(:liquid) if connection.table_exists?(:liquid)

      connection.create_table(:liquid) do |t|
        t.string :name
        t.column :molecule_ids, :roaringbitmap
      end
      connection.create_table(:molecules) do |t|
        t.string :name
        t.bigint :liquid_id
        t.column :electron_ids, :roaringbitmap
      end
      connection.create_table(:electrons) do |t|
        t.string :name
        t.bigint :molecule_id
      end
    end

    it "eager loading should not change count of children" do
      liquid = Liquid.create(:name => "salty")
      molecule = liquid.molecules.create(:name => "molecule_1")
      molecule.electrons.create(:name => "electron_1")
      molecule.electrons.create(:name => "electron_2")
      liquids = Liquid.includes(:molecules => :electrons).references(:molecules).where("molecules.id is not null")
      # binding.pry
      molecules = liquids[0].molecules
      expect(molecules.length).to(eq(1))
    end

    it "update should rollback on failure" do
      liquid = Liquid.create(:name => "salty")
      molecule1 = liquid.molecules.create(:name => "molecule_1")
      molecule1.electrons.create(:name => "electron_1")
      molecule2 = liquid.molecules.create(:name => "molecule_2")
      molecule2.electrons.create(:name => "electron_1")
      molecules_count = liquid.molecules.size
      expect(molecules_count).to eq(2)

      # FixMe:
      # status = liquid.update(:name => nil, :molecule_ids => ([]))#raise    ActiveRecord::StatementInvalid:
      # PG::UndefinedFunction: ERROR:  could not identify an equality operator for type roaringbitmap
      # LINE 1: SELECT DISTINCT "molecules".* FROM "molecules" WHERE "molecu...
      # expect(status).to be false

      # expect(liquid.molecules.reload.size).to eq(molecules_count)
    end

    it "find all using where with relation" do
      david = Author.create(:name => :david)
      query_count_eq(1) do
        relation = Author.where(:id => Author.where(:id => david.id))
        expect(relation.to_a).to(eq([david]))
      end
      query_count_eq(1) do
        relation = Author.where("id in (?)", Author.where(:id => david).select(:id))
        expect(relation.to_a).to(eq([david]))
      end
      query_count_eq(1) do
        relation = Author.where("id in (:author_ids)", :author_ids => Author.where(:id => david).select(:id))
        expect(relation.to_a).to(eq([david]))
      end
    end
  end

  context 'ar_spec classic' do
    let(:connection) { ActiveRecord::Base.connection }

    class Electron < ActiveRecord::Base
      self.table_name = :electrons

      belongs_to :molecule

      validates_presence_of :name
    end

    class Molecule < ActiveRecord::Base
      self.table_name = :molecules

      belongs_to :liquid
      has_many :electrons
      accepts_nested_attributes_for :electrons
    end

    class Liquid < ActiveRecord::Base
      self.table_name = :liquid

      has_many :molecules, -> { distinct }
      accepts_nested_attributes_for :molecules
    end

    before do
      connection.drop_table(:electrons) if connection.table_exists?(:electrons)
      connection.drop_table(:molecules) if connection.table_exists?(:molecules)
      connection.drop_table(:liquid) if connection.table_exists?(:liquid)

      connection.create_table(:liquid) do |t|
        t.string :name
      end
      connection.create_table(:molecules) do |t|
        t.string :name
        t.bigint :liquid_id
      end
      connection.create_table(:electrons) do |t|
        t.string :name
        t.bigint :molecule_id
      end
    end

    # FixMe: sometimes molecule.electrons is empty
    xit "eager loading should not change count of children" do
      liquid = Liquid.create(:name => "salty")
      molecule = liquid.molecules.create(:name => "molecule_1")
      molecule.electrons.create(:name => "electron_1")
      molecule.electrons.create(:name => "electron_2")
      liquids = Liquid.includes(:molecules => :electrons).references(:molecules).where("molecules.id is not null")

      molecules = liquids[0].molecules
      expect(molecules.length).to(eq(1))
    end

    it "update should rollback on failure" do
      author = Author.create(:name => "salty")
      activity = Activity.create(author_id: author.id)
      Post.create(activity: activity, author_id: author.id)
      posts_count = author.posts.size
      expect(posts_count > 0).to be(true)
      status = author.update(:name => nil, :post_ids => ([]))
      expect(status.present?).to be(true)
      expect(author.posts.reload.size).to be_zero
    end

    it "update should rollback on failure" do
      liquid = Liquid.create(:name => "salty")
      molecule1 = liquid.molecules.create(:name => "molecule_1")
      molecule1.electrons.create(:name => "electron_1")
      molecule2 = liquid.molecules.create(:name => "molecule_2")
      molecule2.electrons.create(:name => "electron_1")
      molecules_count = liquid.molecules.size
      expect(molecules_count).to eq(2)
      # FixMe: undefined method `build_changes' for #<ActiveRecord::Associations::HasManyAssociation
      # status = liquid.update(:name => nil, :molecule_ids => ([])) #undefined method `build_changes' for #<ActiveRecord::Associations::HasManyAssociation
      # expect(status).to be false
      expect(liquid.molecules.reload.size).to(eq(molecules_count))
    end

    it "find all using where with relation" do
      david = Author.create(:name => :david)
      query_count_eq(1) do
        relation = Author.where(:id => Author.where(:id => david.id))
        expect(relation.to_a).to(eq([david]))
      end
      query_count_eq(1) do
        relation = Author.where("id in (?)", Author.where(:id => david).select(:id))
        expect(relation.to_a).to(eq([david]))
      end
      query_count_eq(1) do
        relation = Author.where("id in (:author_ids)", :author_ids => Author.where(:id => david).select(:id))
        expect(relation.to_a).to(eq([david]))
      end
    end
  end
end
