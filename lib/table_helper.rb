module ActionView
  module Helpers
    module TableHelper
      # Creates a table for a collection of objects.
      # 
      # In the controller:
      #
      # class PeopleController < ApplicationController
      #   def index
      #     @people = Person.all
      #   end
      # end
      # 
      # In the view:
      #
      # <% table_for @people do |t| %>
      #   <% t.column "First Name", :first_name %>
      #   <% t.column "Last Name", :last_name %>
      #   <% t.column "Age", :age %>
      # <% end %>
      # 
      # A block may be passed. Each record is passed to the block:
      #
      # <% table_for @people do |t|
      #   <% t.column("Full Name") { |person| person.first_name + " " + person.last_name } %>
      # <% end %>
      #
      # An option to using a block is the :helper_method options. Use an an array to pass arguments:
      #
      # <% table_for @files do |t|
      #   <% t.column("Size", :size, :helper_method => :number_to_human_size) %>
      #   <% t.column("File Name", :file_name, :helper_method => [:truncate, 80]) %>
      # <% end %>
      #
      # The above can be shortened by calling the method name on the table yielded to the block:
      #
      # <% table_for @files do |t|
      #   <% t.size("Size"), :helper_method => :number_to_human_size) %>
      #   <% t.file_name("File Name", :helper_method => [:truncate, 80]) %>
      # <% end %>
      #
      # If no column name is defined, the column becomes the humanized method name. The above can be further shortened:
      # 
      # <% table_for @files do |t|
      #   <% t.size :helper_method => :number_to_human_size) %>
      #   <% t.file_name :helper_method => [:truncate, 80]) %>
      # <% end %>
      #
      # HTML attributes can be defined for both the table and column tags, using the :html => {...}. For example:
      #
      #   <% table_for @people, :html => {:id => 'people_table'} do |t| %>
      #     <% t.size :helper_method => :number_to_human_size, :html => {:class => 'numeric'}) %>
      #     ...
      #   <% end %>
      def table_for(collection, options = {}, &proc)
        raise ArgumentError, "Missing block" unless block_given?

        table_definition = TableDefinition.new(self)
        yield(table_definition)
        
        concat(content_tag(:table,
          head_tag(table_definition.columns) + body_tag(table_definition.columns, collection),
          options.delete(:html) || {}),
          proc.binding)
      end
      
      private
        def head_tag(columns)
          content_tag(:thead) do
            content_tag(:tr) do
              columns.map { |column| content_tag(:th, column.name, column.options[:html]) }.to_s
            end
          end
        end
        
        def body_tag(columns, collection)
          content_tag(:tbody) do
            collection.map do |entry|
              cells = columns.map { |column| content_tag(:td, column.format(entry), column.options[:html]) }
              content_tag(:tr, cells * "\n")
            end
          end
        end
    end
  
    class SimpleColumn < Struct.new(:name, :method, :options)
      def format(entry)
        entry.send(method)
      end
    end
  
    class HelperColumn < Struct.new(:name, :method, :helper, :args, :options)
      def format(entry)
        helper.call(entry.send(method), *args)
      end
    end
    
    class ProcColumn < Struct.new(:name, :proc, :options)
      def format(entry)
        proc.call(entry)
      end
    end

    class TableDefinition
      attr_reader :columns, :template
  
      def initialize(template)
        @template = template
        @columns = []
      end

      def column(name, method = nil, options = {}, &proc)
        if method.nil?
          name = name.to_s.humanize
          method = name
        end 
        
        @columns <<
          if block_given?
            ProcColumn.new(name, proc, options)
          elsif options[:helper_method]
            helper_args = helper_method_array(options[:helper_method])
            HelperColumn.new(name, method, template.method(helper_args.shift).to_proc, helper_args, options)
          else
            SimpleColumn.new(name, method, options)
          end
      end
      
      private
      def method_missing(method, *args, &block)
        options = args.extract_options!
        column_name = args.shift || method.to_s.humanize
        column(column_name, method, options, &block)
      end
      
      def helper_method_array(helper_option)
        helper_option.is_a?(Array) ? helper_option : [helper_option]
      end
    end
  end
end