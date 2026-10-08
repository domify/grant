# Crystal-native logging for Grant ORM
#
# Provides structured logging for all Grant operations using Crystal's Log module.
# This enables debugging, monitoring, and performance analysis without the overhead
# of a pub-sub system.
#
# ## Usage
#
# ```
# # Configure logging in your application
# Log.setup do |c|
#   backend = Log::IOBackend.new(formatter: Log::ShortFormat)
#   c.bind "grant.sql", :debug, backend
#   c.bind "grant.model", :info, backend
# end
#
# # SQL queries will be logged automatically
# User.where(active: true).select
# # => [grant.sql] Query executed (1.23ms) - SELECT * FROM users WHERE active = true
# ```

module Grant
  # Main logger for Grant is defined in grant.cr

  # Sub-loggers for different components
  module Logs
    # SQL query logging
    SQL = ::Log.for("grant.sql")

    # Model lifecycle events (create, update, destroy)
    Model = ::Log.for("grant.model")

    # Transaction operations
    Transaction = ::Log.for("grant.transaction")

    # Association loading
    Association = ::Log.for("grant.association")

    # Query builder operations
    Query = ::Log.for("grant.query")

    # The top-level `Log`: what `Log.error { }` wrote from code a macro
    # expands into a model, outside the Grant namespace.
    Top = ::Log.for("")

    # `Grant::Logs.debug(Grant::Logs::SQL) { "..." }` writes what
    # `Grant::Logs::SQL.debug { "..." }` does, through one method compiled
    # once. Log's own methods take the block inline, so each entry written in
    # a generic type or a model was typed again for every model; here only the
    # level check and the message are, built only when the entry is written.
    def self.emit(log : ::Log, severity : ::Log::Severity, exception : Exception?, message : String) : Nil
      case severity
      when .trace?  then log.trace(exception: exception) { message }
      when .debug?  then log.debug(exception: exception) { message }
      when .info?   then log.info(exception: exception) { message }
      when .notice? then log.notice(exception: exception) { message }
      when .warn?   then log.warn(exception: exception) { message }
      when .error?  then log.error(exception: exception) { message }
      when .fatal?  then log.fatal(exception: exception) { message }
      end
    end

    macro trace(log, exception = nil, &block)
      if (%log = {{log}}).level <= ::Log::Severity::Trace
        ::Grant::Logs.emit(%log, ::Log::Severity::Trace, {{exception}}, ({{block.body}}).to_s)
      end
    end

    # :ditto:
    macro debug(log, exception = nil, &block)
      if (%log = {{log}}).level <= ::Log::Severity::Debug
        ::Grant::Logs.emit(%log, ::Log::Severity::Debug, {{exception}}, ({{block.body}}).to_s)
      end
    end

    # :ditto:
    macro info(log, exception = nil, &block)
      if (%log = {{log}}).level <= ::Log::Severity::Info
        ::Grant::Logs.emit(%log, ::Log::Severity::Info, {{exception}}, ({{block.body}}).to_s)
      end
    end

    # :ditto:
    macro notice(log, exception = nil, &block)
      if (%log = {{log}}).level <= ::Log::Severity::Notice
        ::Grant::Logs.emit(%log, ::Log::Severity::Notice, {{exception}}, ({{block.body}}).to_s)
      end
    end

    # :ditto:
    macro warn(log, exception = nil, &block)
      if (%log = {{log}}).level <= ::Log::Severity::Warn
        ::Grant::Logs.emit(%log, ::Log::Severity::Warn, {{exception}}, ({{block.body}}).to_s)
      end
    end

    # :ditto:
    macro error(log, exception = nil, &block)
      if (%log = {{log}}).level <= ::Log::Severity::Error
        ::Grant::Logs.emit(%log, ::Log::Severity::Error, {{exception}}, ({{block.body}}).to_s)
      end
    end

    # :ditto:
    macro fatal(log, exception = nil, &block)
      if (%log = {{log}}).level <= ::Log::Severity::Fatal
        ::Grant::Logs.emit(%log, ::Log::Severity::Fatal, {{exception}}, ({{block.body}}).to_s)
      end
    end
  end

  # Development helpers for pretty logging
  module Development
    # Set up all development logging with pretty formatters
    def self.setup_logging
      setup_sql_logging
      setup_model_logging
      setup_association_logging
      setup_transaction_logging
      setup_query_logging
    end

    # Set up pretty SQL logging for development
    def self.setup_sql_logging
      backend = ::Log::IOBackend.new(STDOUT)
      ::Log.setup do |c|
        c.bind "grant.sql", :debug, backend
      end
    end

    # Set up model logging for development
    def self.setup_model_logging
      backend = ::Log::IOBackend.new(STDOUT)
      ::Log.setup do |c|
        c.bind "grant.model", :debug, backend
      end
    end

    # Set up association logging for development
    def self.setup_association_logging
      backend = ::Log::IOBackend.new(STDOUT)
      ::Log.setup do |c|
        c.bind "grant.association", :debug, backend
      end
    end

    # Set up transaction logging for development
    def self.setup_transaction_logging
      backend = ::Log::IOBackend.new(STDOUT)
      ::Log.setup do |c|
        c.bind "grant.transaction", :debug, backend
      end
    end

    # Set up query builder logging for development
    def self.setup_query_logging
      backend = ::Log::IOBackend.new(STDOUT)
      ::Log.setup do |c|
        c.bind "grant.query", :debug, backend
      end
    end

    # Note: Custom formatters removed due to Crystal Log API changes
    # Logging now uses standard formatters
  end
end
