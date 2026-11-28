# frozen_string_literal: true

require "active_record"

# One in-memory database for every spec file that needs ActiveRecord (a second
# establish_connection would throw away the first file's tables).
unless ActiveRecord::Base.connected?
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  ActiveRecord::Schema.verbose = false
end
