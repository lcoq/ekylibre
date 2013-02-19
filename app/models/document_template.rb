# -*- coding: utf-8 -*-
# = Informations
#
# == License
#
# Ekylibre - Simple ERP
# Copyright (C) 2009-2013 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: document_templates
#
#  active       :boolean          not null
#  by_default   :boolean          default(TRUE), not null
#  cache        :text
#  code         :string(32)
#  country      :string(2)
#  created_at   :datetime         not null
#  creator_id   :integer
#  family       :string(32)
#  filename     :string(255)
#  id           :integer          not null, primary key
#  language     :string(3)        default("???"), not null
#  lock_version :integer          default(0), not null
#  name         :string(255)      not null
#  nature       :string(64)
#  source       :text
#  to_archive   :boolean
#  updated_at   :datetime         not null
#  updater_id   :integer
#


class DocumentTemplate < Ekylibre::Record::Base
  # Be careful! :id is a forbidden name for parameters
  @@document_natures = {
    :animal =>           [ [:animal, Product]],
    :balance_sheet =>    [ [:financial_year, FinancialYear] ],
    :entity =>           [ [:entity, Entity] ],
    :deposit =>          [ [:deposit, Deposit] ],
    :income_statement => [ [:financial_year, FinancialYear] ],
    :inventory =>        [ [:inventory, Inventory] ],
    :sales_invoice =>    [ [:sales_invoice, Sale] ],
    :journal =>          [ [:journal, Journal], [:started_on, Date], [:stopped_on, Date] ],
    :general_journal =>  [ [:started_on, Date], [:stopped_on, Date] ],
    :general_ledger =>   [ [:started_on, Date], [:stopped_on, Date] ],
    :purchase =>         [ [:purchase, Purchase] ],
    :sales =>            [ [:established_on, Date] ],
    :sales_order =>      [ [:sales_order, Sale] ],
    :stocks =>           [ [:established_on, Date] ],
    :transport =>        [ [:transport, Transport] ]
  }
  attr_accessible :active, :by_default, :code, :country, :family, :filename, :language, :name, :nature, :source, :to_archive
  after_save :set_by_default
  cattr_reader :document_natures
  # TODO Do we keep DocumentTemplate families ?
  enumerize :family, :in => [:company, :relations, :accountancy, :management, :production], :predicates => true
  enumerize :nature, :in => self.document_natures.keys, :predicates => {:prefix => true}
  has_many :documents, :foreign_key => :template_id
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_length_of :country, :allow_nil => true, :maximum => 2
  validates_length_of :language, :allow_nil => true, :maximum => 3
  validates_length_of :code, :family, :allow_nil => true, :maximum => 32
  validates_length_of :nature, :allow_nil => true, :maximum => 64
  validates_length_of :filename, :name, :allow_nil => true, :maximum => 255
  validates_inclusion_of :active, :by_default, :in => [true, false]
  validates_presence_of :language, :name
  #]VALIDATORS]
  validates_presence_of :filename, :nature, :family, :code
  validates_uniqueness_of :code
  validates_inclusion_of :family, :in => self.family.values
  validates_inclusion_of :nature, :in => self.nature.values

  include ActionView::Helpers::NumberHelper

  # @@families = [:company, :relations, :accountancy, :management, :production] # :resources,


  # [:balance, :sales_invoice, :sale, :purchase, :inventory, :transport, :deposit, :entity, :journal, :ledger, :other]

  # include ActionView::Helpers::NumberHelper


  default_scope order(:name)
  scope :of_nature, lambda { |nature|
    raise ArgumentError.new("Unknown nature for a DocumentTemplate (got #{nature.inspect}:#{nature.class})") unless self.nature.values.include?(nature.to_s)
    where(:nature => nature.to_s, :active => true).order(:name)
  }


  before_validation do
    self.filename ||= 'document'
    self.cache = Templating.compile(self.source, :xil) # rescue nil
    self.by_default = true if self.class.find_all_by_nature_and_by_default(self.nature, true).size <= 0
    return true
  end

  validate do
    errors.add(:source, :invalid) if self.cache.blank?
    if self.nature != "other"
      syntax_errors = self.filename_errors
      errors.add(:filename, :invalid_syntax, :errors => syntax_errors.to_sentence) unless syntax_errors.empty?
    end
  end

  def set_by_default# (by_default=nil)
    if self.nature != 'other' and self.class.count(:conditions => {:by_default => true, :nature => self.nature}) != 1
      self.class.update_all({:by_default => true}, {:id => self.id})
      self.class.update_all({:by_default => false}, ["id != ? and nature = ?", self.id, self.nature])
    end
  end

  protect(:on => :destroy) do
    self.documents.size <= 0
  end


  # Print document without checks fast but dangerous if parameters are not checked before...
  # Use carefully
  def print_fastly!(*args)
    # Refresh cache if needed
    self.save! unless self.cache.starts_with?(Templating.preamble)

    # Try to find an existing archive
    owner = args[0].class.ancestors.include?(ActiveRecord::Base) ? args[0] : Company.first
    if self.to_archive and owner.is_a?(ActiveRecord::Base)
      document = Document.where(:nature_code => self.code, :owner_id => owner.id, :owner_type => owner.class.name).order("created_at DESC").first
      return document.data, document.original_name if document
    end

    # Build the PDF data
    # self.cache.split("\n").each_with_index{|l,x| puts((x+1).to_s.rjust(4)+": "+l)}
    pdf = eval(self.cache)

    # Archive the document if necessary
    document = self.archive(owner, pdf, :extension => 'pdf') if self.to_archive

    return pdf, self.compute_filename(owner) + ".pdf"
  end




  # Print document raising Exceptions if necessary
  def print!(*args)
    # Refresh cache if needed
    self.save! unless self.cache.starts_with?(Templating.preamble)

    # Analyze and cleans parameters
    parameters = self.class.document_natures[self.nature.to_sym]
    raise StandardError.new(tc(:unvalid_nature)) if parameters.nil?
    if args[0].is_a? Hash
      hash = args[0]
      parameters.each_index do |i|
        args[i] = hash[parameters[i][0]]||hash["p"+i.to_s]
      end
    end
    raise ArgumentError.new("Bad number of arguments, #{args.size} for #{parameters.size}") if args.size != parameters.size

    parameters.each_index do |i|
      args[i] = parameters[i][1].find_by_id(args[i].to_s.to_i) if parameters[i][1].ancestors.include?(ActiveRecord::Base) and not args[i].is_a? parameters[i][1]
      args[i] = args[i].to_date if args[i].class == String and parameters[i][1] == Date
      raise ArgumentError.new("#{parameters[i][1].name} expected, got #{args[i].inspect}") unless args[i].class == parameters[i][1]
    end

    # Try to find an existing archive
    if self.to_archive and args[0].class.ancestors.include?(ActiveRecord::Base)
      document = Document.where(:nature_code => self.code, :owner_id => owner.id, :owner_type => owner.class.name).order("created_at DESC").first
      return document.data, document.original_name if document
    end

    # Build the PDF data
    begin
      pdf = eval(self.cache)
    rescue Exception => e
      puts e.message+"\nCache:\n"+self.cache
      raise e
    end

    # Archive the document if necessary
    document = self.archive(owner, pdf, :extension => 'pdf') if self.to_archive

    return pdf, self.compute_filename(owner)+".pdf"
  end


  # Print document or exception if necessary
  def print(*args)
    begin
      return self.print!(*args)
    rescue Exception => e
      return self.class.error_document(e)
    end
  end

  # Print! a document
  def self.print(nature, options = {})
    template ||= options[:template]
    template = if template.is_a? String or template.is_a? Symbol
                 self.find_by_active_and_nature_and_code(true, nature, template)
               else
                 self.find_by_active_and_nature_and_by_default(true, nature, true)
               end
    raise ArgumentError.new("Unfound template") unless template
    parameters = []
    for p in self.document_natures[nature.to_sym]
      x = options[p[0]]
      raise ArgumentError.new("options[:#{p[0]}] must be a #{p[1].name} (got #{x.class.name})") if x.class != p[1]
      parameters << x
    end
    return template.print_fastly!(*parameters)
  end


  def filename_errors
    errors = []
    begin
      klass = self.class.document_natures[self.nature.to_sym][0][1]
      columns = klass.content_columns.collect{|x| x.name.to_s}.sort
      self.filename.gsub(/\[\w+\]/) do |word|
        unless columns.include?(word[1..-2])
          errors << tc(:error_attribute, :value => word, :possibilities => columns.collect { |column| column+" ("+klass.human_attribute_name(column)+")" }.join(", "))
        end
        "*"
      end
    rescue
      #   errors << tc(:nature_do_not_allow_to_use_attributes)
    end
    return errors
  end

  def compute_filename(object)
    if self.nature == "other" #||"card"
      filename = self.filename
    elsif self.filename_errors.empty?
      filename = self.filename.gsub(/\[\w+\]/) do |word|
        #raise Exception.new "2"+filename.inspect
        object.attributes[word[1..-2]].to_s rescue ""
      end
    else
      return tc(:invalid_filename)
    end
    return filename
  end

  def archive(owner, data, attributes={})
    document = self.documents.build
    document.owner = owner
    document.extension = attributes[:extension] || "bin"
    method_name = [:document_name, :number, :code, :name, :id].detect{|x| owner.respond_to?(x)}
    document.printed_at = Time.now
    document.subdir = Date.today.strftime('%Y-%m')
    document.original_name = owner.send(method_name).to_s.simpleize+'.'+document.extension.to_s
    document.filename = owner.send(method_name).to_s.codeize+'-'+document.printed_at.to_i.to_s(36).upper+'-'+Document.generate_key+'.'+document.extension.to_s
    document.filesize = data.length
    document.sha256 = Digest::SHA256.hexdigest(data)
    document.crypt_mode = 'none'
    if document.save
      FileUtils.mkdir_p(document.path)
      File.open(document.file_path, 'wb') {|f| f.write(data) }
    else
      raise Exception.new(document.errors.inspect)
    end
    return document
  end


  def sample
    self.save!
    code = Templating.compile(self.source, :xil, :mode => :debug)
    pdf = nil
    # code.split("\n").each_with_index{|l,x| puts((x+1).to_s.rjust(4)+": "+l)}
    begin
      pdf = eval(code)
    rescue Exception => e
      pdf = self.class.error_document(e)
    end
    pdf
  end

  # Generate a copy of the template with a different code.
  def duplicate
    attrs = self.attributes.dup
    attrs.delete("id")
    attrs.delete("lock_version")
    attrs.delete_if{|k,v| k.match(/^(cre|upd)at((e|o)r_id|ed_(at|on))/) }
    while self.class.where(:code => attrs["code"]).first
      attrs["code"].succ!
    end
    return self.class.create(attrs, :without_protection => true)
  end


  # Produces a generic document with the trace of the thrown exception
  def self.error_document(exception)
    Templating::Writer.generate do |doc|
      doc.page(:size => "A4", :margin => 15.mm) do |p|
        if exception.is_a? Exception
          p.slice do |s|
            s.text("Exception: "+exception.inspect)
          end
          for item in exception.backtrace
            p.slice do |s|
              s.text(item)
            end
          end
        else
          p.slice do |s|
            s.text("Error: "+exception.inspect, :width => 180.mm)
          end
        end
      end
    end
  end


  # Loads in DB all default document templates
  def self.load_defaults(options = {})
    locale = (options[:locale] || Entity.of_company.language || I18n.locale).to_s
    country = Entity.of_company.country || 'fr'
    files_dir = Rails.root.join("config", "locales", locale, "prints")
    all_templates = ::I18n.translate('models.document_template.default') || {}
    for family, templates in all_templates
      for template, attributes in templates
        next unless File.exist? files_dir.join("#{template}.xml")
        File.open(files_dir.join("#{template}.xml"), "rb:UTF-8") do |f|
          nature, code = (attributes[:nature] || template), template.to_s # attributes[:name].to_s.codeize[0..7]
          doc = self.find_by_code(code) || self.new(:code => code)
          doc.attributes = HashWithIndifferentAccess.new(:active => true, :language => locale, :country => country, :family => family, :by_default => false, :nature => nature, :filename => (attributes[:filename] || "File"))
          doc.name = (attributes[:name] || doc.nature.text).to_s
          doc.to_archive = true if attributes[:to_archive] == "true"
          doc.source = f.read.force_encoding('UTF-8')
          doc.save!
        end
      end
    end if all_templates.is_a?(Hash)
    return true
  end

end
