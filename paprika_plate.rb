# frozen_string_literal: true

require 'webdrivers'
require 'watir'
require 'base64'
require 'open-uri'
require 'yaml'

# Scrapes PepperPlate and returns recipes in Paprika YML format
class PaprikaPlate
  def self.run
    browser = Watir::Browser.new :chrome, headless: true
    paprika_plate = PaprikaPlate.new(browser)
    paprika_plate.sign_in

    recipe_urls = paprika_plate.load_recipe_urls
    paprika_plate.loop_through_recipes(recipe_urls)
    paprika_plate.write_recipes_to_file
  end

  def sign_in
    email = ask_for_email
    password = ask_for_password

    puts 'Signing in...'

    @browser.goto 'https://www.pepperplate.com/login.aspx'
    @browser.text_field(id: 'cphMain_loginForm_tbEmail').set email
    @browser.text_field(id: 'cphMain_loginForm_tbPassword').set password
    @browser.link(id: 'cphMain_loginForm_ibSubmit').click!

    return if @browser.link(text: 'Sign Out').exists?

    raise 'Could not sign you in. '\
          'Check your username and password are correct.'
  end

  def load_recipe_urls
    puts 'Loading recipe links...'

    number_of_recipes_text = @browser.div(id: 'reclistcount').text
    if number_of_recipes_text.empty?
      raise 'Could not determine number of recipes.'
    end

    number_of_recipes = /\d+/.match(number_of_recipes_text)[0].to_i

    urls = @browser.divs(class: 'item').map { |div| div.link.href }.uniq

    while urls.count < number_of_recipes
      @browser.link(id: 'loadmorelink').click!
      urls = @browser.divs(class: 'item').map { |div| div.link.href }.uniq
    end

    return urls unless urls.count < number_of_recipes

    raise "Could only load links for #{urls.count} of #{number_of_recipes} " \
          "recipes."
  end

  def loop_through_recipes(recipe_urls)
    puts "Loaded #{recipe_urls.count} recipe links."

    recipe_urls.each do |url|
      @browser.goto url
      @recipes << read_recipe
    end
  end

  def write_recipes_to_file
    File.open('recipes.yaml', 'w') do |file|
      @recipes.each do |recipe|
        file.write(format_recipe(recipe))
      end
    end
  end

  private

  def initialize(browser)
    @browser = browser
    @recipes = []
  end

  def ask_for_email
    puts 'Enter the email address associated with your PepperPlate account:'
    gets.chomp
  end

  def ask_for_password
    puts 'Enter the password for your PepperPlate account:'
    gets.chomp
  end

  def read_recipe
    recipe = {}

    recipe[:name] = @browser.h2.text
    puts "Reading \"#{recipe[:name]}\"..."

    source = @browser.link(class: 'source')
    if source.exists?
      recipe[:source] = source.text
      recipe[:source_url] = source.href
    end

    description = @browser.p(class: 'desc').text
    recipe[:description] = description unless description.empty?

    servings_span = @browser.span(id: 'cphMiddle_cphMain_lblYield')
    recipe[:servings] = servings_span.text if servings_span.exists?

    active_time_span = @browser.span(id: 'cphMiddle_cphMain_lblActiveTime')
    recipe[:prep_time] = active_time_span.text if active_time_span.exists?

    categories_div = @browser.div(id: 'cphMiddle_cphMain_pnlTags')
    if categories_div.exists?
      recipe[:categories] = categories_div.span.text.split(', ')
    end

    notes = @browser.span(id: 'cphMiddle_cphMain_lblNotes').text
    recipe[:notes] = [notes] unless notes.empty?

    image_element = @browser.image(id: 'cphMiddle_cphMain_imgRecipeThumb')
    recipe[:photo] = recipe_image(image_element) if image_element.exists?

    recipe[:ingredients] = read_ingredients
    recipe[:directions] = read_directions

    recipe
  end

  def recipe_image(image_element)
    uri = URI.parse(image_element.src)
    Base64.strict_encode64(uri.open(&:read))
  end

  def read_ingredients
    ingredient_groups = @browser.ul(class: 'inggroups')
    ingredient_groups.lis(class: 'item').map(&:text)
  end

  def read_directions
    direction_groups = @browser.ul(class: 'dirgroups')
    direction_groups.spans(class: 'text').map(&:text)
  end

  def format_recipe(recipe)
    yaml = "- name: #{recipe[:name]}\n"
    recipe.delete(:name)

    recipe.each do |key, value|
      if %i[ingredients directions notes].include? key
        next if value.empty?

        yaml += "  #{key}: |\n"
        value.each { |item| yaml += "    #{item}\n" }
        next
      end

      yaml += "  #{key}: #{value}\n"
    end

    yaml
  end
end

PaprikaPlate.run
