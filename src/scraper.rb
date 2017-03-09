require "capybara"
require "capybara/dsl"
require_relative "./hearing"

module Scraper
  class << self
    include Capybara::DSL
  end

  def self.run
    # fake user agent to avoid getting redirected to error pages
    # find alternatives here: https://techblog.willshouse.com/2012/01/03/most-common-user-agents/
    page.driver.headers = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2924.87 Safari/537.36"
    }

    # scrape and aggregate results from chamber pages
    puts "- starting scrape"

    chamber_urls = [
      "http://my.ilga.gov/Hearing/AllHearings?chamber=H",
      "http://my.ilga.gov/Hearing/AllHearings?chamber=S"
    ]

    hearings = hearings_from_chamber_pages(chamber_urls)
    bills = hearings.flat_map(&:bills)

    puts "\n- finished scrape:"
    puts "  hearings: #{hearings.count}"
    puts "  bills: #{bills.count}"
  end

  private

  def self.hearings_from_chamber_pages(chamber_urls)
    chamber_urls.reduce([]) do |hearings, chamber_url|
      hearings + hearings_from_chamber_page(chamber_url)
    end
  end

  def self.hearings_from_chamber_page(url)
    puts "\n- visit chamber"
    puts "  url: #{url}"

    # committee data is pulled in by xhr so we have to sleep, we could try
    # hitting that api directly (its data is much richer)
    visit(url)
    sleep(1)

    # click the month tab to view all the upcoming hearings
    month_tab = page.find("#CommitteeHearingTabstrip li a", text: "Month")
    month_tab.click
    sleep(1)

    # get the all hearings from the monthly tab
    hearings_from_monthly_chamber_page
  end

  def self.hearings_from_monthly_chamber_page(url = nil)
    # we're assumed to already be here if no url is given
    if (!url.nil?)
      visit(url)
      sleep(1)
    end

    # find all hearing links on this page
    hearing_rows = page.find_all("#CommitteeHearingTabstrip tbody tr")
    hearings = hearing_rows.map do |row|
      hearing = hearing_from_row(row)
    end

    # find all bills for each hearing
    hearings.each do |hearing|
      hearing.bills = bills_from_hearing_page(hearing.url)
    end

    # aggregate the next page's results if it's available
    next_page_url = find_next_page_url
    puts "  next?: #{!next_page_url.nil?}"
    next_page_url.nil? ? hearings : hearing + hearings_from_monthly_chamber_page(next_page_url)
  end

  def self.hearing_from_row(row)
    columns = row.find_all("td")

    # construct the hearing with available attributes
    # TODO: it looks like there might be ids in hidden tds
    hearing = Hearing.new
    hearing.date_time = columns[0]&.text
    hearing.url = columns[2]&.find("a")["href"]

    name_location = columns[1]
    hearing.committee_name = name_location.find("strong").text
    hearing.location = name_location.text[hearing.committee_name.length..-1].strip

    hearing
  end

  def self.bills_from_hearing_page(url)
    puts "\n- visit committee"
    puts "  url: #{url}"

    visit(url)

    # find all bills on this page
    bill_rows = page.find_all("#GridCurrentCommittees tbody tr")
    bills = bill_rows.map do |row|
      bill_from_row(row)
    end.compact
    puts "  bills: #{bills.count}"

    # aggregate the next page's results if it's available
    next_page_url = find_next_page_url
    puts "  next?: #{!next_page_url.nil?}"
    next_page_url.nil? ? bills : bills + bills_from_hearing_page(next_page_url)
  end

  def self.bill_from_row(row)
    # short circuit if we can't find a link
    witness_slip_link = row.first(".slipiconbutton")
    if witness_slip_link.nil?
      return nil
    end

    columns = row.find_all("td")

    # construct the bill with available attributes
    # TODO: it looks like there might be an id in a hidden td
    bill = Bill.new
    bill.document_number = columns[0]&.text
    bill.sponsor_name = columns[1]&.text
    bill.description = columns[2]&.text
    bill.witness_slip_url = witness_slip_link["href"]

    bill
  end

  # helpers
  def self.find_next_page_url
    next_page_button = page.find(".t-arrow-next").first(:xpath, ".//..")
    has_next_page = !next_page_button[:class].include?("t-state-disabled")
    has_next_page ? next_page_button["href"] : nil
  end

  def self.take_screenshot(page, title="screenshot.png")
    page.save_screenshot(title)
  end
end
