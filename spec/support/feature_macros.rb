##
# Perform the actions a user would do to login.
#
# This method is intended to be called during an acceptance (also called feature) test.

def login_user_for_feature(user)
  visit new_user_session_path
  fill_in 'Email', with: user.email
  fill_in 'Password', with: user.password
  click_on 'Sign in'
end

##
# Test that a user is logged in, during an acceptance test.
#
# To see if the user is logged in, we check the presence of a "Logout" link in the navbar.

def user_should_be_logged_in
  page.should have_css 'div.navbar div.navbar-inner ul li a#sign_out'
end

##
# Test that a user is not logged in, during an acceptance test.
#
# To see if the user is not logged in, we check the absence of a "Logout" link in the navbar.

def user_should_not_be_logged_in
  page.should_not have_css 'div.navbar div.navbar-inner ul li a#sign_out'
end

##
# Test that an email has been sent during acceptance testing. Accepts an options hash supporting the following options:
#
# - :path - if passed, tests that the mail contains a link to this path. Ideally we'd like to test using full URLs
# but this not possible because during testing links inside emails generated by ActionMailer use the hostname
# "www.example.com" instead of the actual "localhost:3000" returned by Rails URL helpers.
# - :to - if passed, tests that this is the value of the email's "to" header.
#
# Return value is the href of the link if "path" option is passed, nil otherwise.

def mail_should_be_sent(options={})
  default_options = {path: nil, to: nil}
  options = default_options.merge options

  email = ActionMailer::Base.deliveries.pop
  email.present?.should be_true

  if options[:path].present?
    emailBody = Nokogiri::HTML email.body.to_s
    link = emailBody.at_css "a[href*=\"#{options[:path]}\"]"
    link.present?.should be_true
    href = link[:href]
  end

  if options[:to].present?
    email.to.first.should eq options[:to]
  end

  return href
end

##
# Test that no email has been sent during acceptance testing

def mail_should_not_be_sent
  email = ActionMailer::Base.deliveries.pop
  email.present?.should be_false
end

##
# Click on a feed to read its entries during acceptance testing

def read_feed(feed_id)
  within 'ul#sidebar li#folder-all' do
    # Open "All subscriptions" folder
    find("a[data-target='#feeds-all']").click

    page.should have_css "li > a[data-feed-id='#{feed_id}']"

    # Click on feed to read its entries
    find("li > a[data-feed-id='#{feed_id}']").click
  end
end