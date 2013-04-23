# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$(document).ready ->

##########################################################
# DYNAMIC STYLES
##########################################################

  # Dynamic styling when clicking on the sidebar folders
  $(".menu-level1").click ->
    $(this).children("i.arrow").toggleClass "icon-chevron-right"
    $(this).children("i.arrow").toggleClass "icon-chevron-down"
    $(this).children("i.folder").toggleClass "icon-folder-close-alt"
    $(this).children("i.folder").toggleClass "icon-folder-open-alt"

  # Dynamid styling when clicking on a feed in the sidebar
  $("[data-feed]").click ->
    $("[data-feed]").parent().removeClass "active"
    $(this).parent().addClass "active"

##########################################################
# AJAX
##########################################################

  # Load new feed entries when clicking on the Refresh button
  $("[data-refresh-feed]").click ->
    feed_id = $(this).attr "data-refresh-feed"
    # Only refresh if the data-refresh-feed attribute has a reference to a feed id
    if feed_id?.length
      $("> i.icon-repeat", this).addClass "icon-spin"
      # Function to insert new entries in the list
      insert_entries = (entries, status, xhr) ->
        $("[data-refresh-feed] > i.icon-repeat").removeClass "icon-spin"
        if status in ["error", "timeout", "abort", "parsererror"]
          $("#alert p").text "There has been a problem refreshing the feed. Please try again later"
          $("#alert").removeClass "hidden"
      $("#feed-entries").load "/feeds/#{feed_id}/refresh", null, insert_entries

  # Load current feed entries when clicking on a feed in the sidebar
  $("[data-feed]").click ->
    # Function to insert new entries in the list
    insert_entries = (entries, status, xhr) ->
      if status in ["error", "timeout", "abort", "parsererror"]
        $("#alert p").text "There has been a problem refreshing the feed. Please try again later"
        $("#alert").removeClass "hidden"
    feed_id = $(this).attr "data-feed"
    $("#feed-entries").load "/feeds/#{feed_id}", null, insert_entries
    # The refresh button now refreshes the feed_id feed
    $("[data-refresh-feed]").attr "data-refresh-feed", feed_id
