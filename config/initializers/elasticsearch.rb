Post.__elasticsearch__.client = Elasticsearch::Client.new(log: true, url: 'http://localhost:9201')
Post.__elasticsearch__.create_index!
Post.import