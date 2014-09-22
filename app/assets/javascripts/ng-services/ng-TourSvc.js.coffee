########################################################
# AngularJS service to show application tours
########################################################

angular.module('feedbunch').service 'tourSvc',
['$rootScope', '$http', 'timerFlagSvc', ($rootScope, $http, timerFlagSvc)->

  #--------------------------------------------
  # Media query to show the main app tour only in screens bigger than a smartphone
  #--------------------------------------------
  sm_min_media_query = 'screen and (min-width: 768px)'

  #--------------------------------------------
  # Media query to show the mobile app tour only in smartphone-sized screens
  #--------------------------------------------
  xs_max_media_query = 'screen and (max-width: 768px)'

  #--------------------------------------------
  # PRIVATE FUNCTION: set to false the show_main_tour flag for the current user.
  #--------------------------------------------
  dont_show_main_tour = ->
    $rootScope.show_main_tour = false
    $http.put("/api/user_config.json", user_config: {show_main_tour: 'false'})
    .error (data, status)->
      timerFlagSvc.start 'error_changing_show_tour' if status!=0

  #--------------------------------------------
  # PRIVATE FUNCTION: set to false the show_mobile_tour flag for the current user.
  #--------------------------------------------
  dont_show_mobile_tour = ->
    $rootScope.show_mobile_tour = false
    $http.put("/api/user_config.json", user_config: {show_mobile_tour: 'false'})
    .error (data, status)->
      timerFlagSvc.start 'error_changing_show_tour' if status!=0

  #--------------------------------------------
  # PRIVATE FUNCTION: set to false the show_feed_tour flag for the current user.
  #--------------------------------------------
  dont_show_feed_tour = ->
    $rootScope.show_feed_tour = false
    $http.put("/api/user_config.json", user_config: {show_feed_tour: 'false'})
    .error (data, status)->
      timerFlagSvc.start 'error_changing_show_tour' if status!=0

  service =
    #---------------------------------------------
    # Show the main application tour.
    #---------------------------------------------
    show_main_tour: ->
      # The main tour is only shown in screens bigger than a smartphone
      enquire.register sm_min_media_query, ->
        now = new Date()
        $http.get("/api/tours/main.json?time=#{now.getTime()}")
        .success (data)->
          tour =
            id: 'main-tour',
            showCloseButton: true,
            showPrevButton: true,
            showNextButton: true,
            onEnd: dont_show_main_tour,
            onClose: dont_show_main_tour,
            i18n: data['i18n'],
            steps: data['steps']
          hopscotch.startTour tour
        .error (data, status)->
          timerFlagSvc.start 'error_loading_tour' if status!=0

    #---------------------------------------------
    # Show the mobile application tour.
    #---------------------------------------------
    show_mobile_tour: ->
      # The mobile tour is only shown in smartphone-sized screens
      enquire.register xs_max_media_query, ->
        now = new Date()
        $http.get("/api/tours/mobile.json?time=#{now.getTime()}")
        .success (data)->
          tour =
            id: 'mobile-tour',
            showCloseButton: true,
            showPrevButton: true,
            showNextButton: true,
            onEnd: dont_show_mobile_tour,
            onClose: dont_show_mobile_tour,
            i18n: data['i18n'],
            steps: data['steps']
          hopscotch.startTour tour
        .error (data, status)->
          timerFlagSvc.start 'error_loading_tour' if status!=0

    #---------------------------------------------
    # Show the main application tour.
    #---------------------------------------------
    show_feed_tour: ->
      # The feed tour is only shown in screens bigger than a smartphone
      enquire.register sm_min_media_query, ->
        now = new Date()
        $http.get("/api/tours/feed.json?time=#{now.getTime()}")
        .success (data)->
          tour =
            id: 'feed-tour',
            showCloseButton: true,
            showPrevButton: true,
            showNextButton: true,
            onEnd: dont_show_feed_tour,
            onClose: dont_show_feed_tour,
            i18n: data['i18n'],
            steps: data['steps']
          hopscotch.startTour tour
        .error (data, status)->
          timerFlagSvc.start 'error_loading_tour' if status!=0

  return service

]