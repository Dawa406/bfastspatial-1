####################################################################################
####### BFAST
####### SEPAL shiny application
####### FAO Open Foris SEPAL project
####### remi.dannunzio@fao.org - yelena.finegold@fao.org
####################################################################################

####################################################################################
# FAO declines all responsibility for errors or deficiencies in the database or
# software or in the documentation accompanying it, for program maintenance and
# upgrading as well as for any # damage that may arise from them. FAO also declines
# any responsibility for updating the data and assumes no responsibility for errors
# and omissions in the data provided. Users are, however, kindly asked to report any
# errors or deficiencies in this product to FAO.
####################################################################################

####################################################################################
## Last update: 2019/03/21
## bfast / server # branch for tiling internal
####################################################################################


####################################################################################
####### Start Server

shinyServer(function(input, output, session) {
  ####################################################################################
  ##################### Choose language option             ###########################
  ####################################################################################
  output$chosen_language <- renderPrint({
    if (input$language == "English") {
      source("www/scripts/text_english.R",
             local = TRUE,
             encoding = "UTF-8")
      #print("en")
    }
    if (input$language == "Français") {
      source("www/scripts/text_french.R", 
             local = TRUE, 
             encoding = "UTF-8")
      #print("fr")
    }
    if (input$language == "Español") {
      source("www/scripts/text_spanish.R",
             local = TRUE,
             encoding = "UTF-8")
      #print("sp")
    }
  })
  
  ##################################################################################################################################
  ############### Stop session when browser is exited
  
  session$onSessionEnded(stopApp)
  
  ##################################################################################################################################
  ############### Show progress bar while loading everything
  options(echo=TRUE)
  progress <- shiny::Progress$new()
  progress$set(message = "Loading data", value = 0)
  
  ####################################################################################
  ####### Step 0 : read the map file and store filepath    ###########################
  ####################################################################################
  
  ##################################################################################################################################
  ############### Find volumes
  osSystem <- Sys.info()["sysname"]
  
  volumes <- list()
  media <- list.files("/media", full.names = T)
  names(media) = basename(media)
  volumes <- c(media)
  
  volumes <- c('Home' = Sys.getenv("HOME"),
               volumes)
  
  my_zip_tools <- Sys.getenv("R_ZIPCMD", "zip")
  
  
  ##################################################################################################################################
  ## Allow to download test data
  output$dynUI_download_test <- renderPrint({
    req(input$download_test_button)
    
    dir.create(file.path("~", "bfast_data_test"),showWarnings = F)
    
    withProgress(message = paste0('Downloading data in ', dirname("~/bfast_data_test/")),
                 value = 0,
                 {
                   if(input$example_dataset == "Liberia example"){
                   system("wget -O ~/bfast_data_test/bfast_data_test.zip https://www.dropbox.com/s/1f8s15rg6er2y2g/liberia_ts_example.zip")
                   system("unzip -o ~/bfast_data_test/bfast_data_test.zip -d ~/bfast_data_test/")
                   system("rm ~/bfast_data_test/bfast_data_test.zip")
                   }
                   if(input$example_dataset == "Kenya example 2"){
                     system("wget -O ~/bfast_data_test/kn_ts_smallarea2_ndvi_2013_2019.zip https://www.dropbox.com/s/r9stcaaf59i4nz9/kn_ts_smallarea2_ndvi_2013_2019.zip")
                     system("unzip -o ~/bfast_data_test/kn_ts_smallarea2_ndvi_2013_2019.zip  -d ~/bfast_data_test/ ")
                     system("rm ~/bfast_data_test/kn_ts_smallarea2_ndvi_2013_2019.zip")
                   }
                   if(input$example_dataset == "Kenya example 1"){
                     system("wget -O ~/bfast_data_test/bfast_data_kenya1_test.zip https://www.dropbox.com/s/jsxwp8rp3tlcyc2/TS_kenya_L8_2013_2018.zip")
                     system("unzip -o ~/bfast_data_test/bfast_data_kenya1_test.zip  -d ~/bfast_data_test/ ")
                     system("rm ~/bfast_data_test/bfast_data_kenya1_test.zip")
                   } 
              
                   
                 })
    
    list.files("~/bfast_data_test/")
  })
  
  ##################################################################################################################################
  ############### Select input file (raster OR vector)
  shinyDirChoose(
    input,
    'time_series_dir',
    roots = volumes,
    session = session,
    restrictions = system.file(package = 'base')
  )
  
  ##################################################################################################################################
  ############### Select Forest-Non Forest mask
  shinyFileChoose(
    input,
    'mask_file',
    filetype = "tif",
    roots = volumes,
    session = session,
    restrictions = system.file(package = 'base')
  )
  
  
  ##################################################################################################################################
  ############### CREATE A BUTTON THAT SHOWS ONLY IF OPTION SELECTED
  output$ui_button_mask <- renderUI({
    req(input$time_series_dir)
    req(input$option_useMask == "FNF Mask")
    
    shinyFilesButton(id = 'mask_file',
                     label = "Mask file",  
                     title = "Browse",
                     multiple=F)
  })
  
  ################################# Data file path
  data_dir <- reactive({
    validate(need(input$time_series_dir, "Missing input: Please select time series folder"))
    req(input$time_series_dir)
    df <- parseDirPath(volumes, input$time_series_dir)
  })
  
  
  ################################# Display tiles inside the DATA_DIR
  output$outdirpath = renderPrint({
    req(input$time_series_dir)
    paste0("File: ",data_dir()," Tile: ",basename(list.dirs(data_dir(),recursive = F)))
  })
  
  
  ################################# Output directory path
  mask_file_path <- reactive({
    req(input$mask_file)
    
    df <- parseFilePaths(volumes, input$mask_file)
    file_path <- as.character(df[, "datapath"])

  })
  
  ################################# Print selected mask file
  output$print_mask_file <- renderPrint({
    req(input$mask_file)
    req(input$option_useMask == "FNF Mask")
    df <- parseFilePaths(volumes, input$mask_file)
    as.character(df[, "datapath"])
  })
  
  ################################# Setup from the archives the Date Range
  list_year <- reactive({
    req(data_dir())
    data_dir <- data_dir()
    first <- list.dirs(data_dir,recursive = F)[1]
    dates <- unlist(read.csv(paste0(first,'/','dates.csv'),header = FALSE))
    list_year <- str_split_fixed(unlist(dates),"-",3)[,1]
    # list <- list.files(data_dir,pattern = glob2rx("*_stack*.tif"),recursive = T)
    # unlist(lapply(list,function(x){unlist(strsplit(x,split = "_"))[length(unlist(strsplit(x,split = "_")))-1]}))
  })
  
  ################################# Take the minimum as beginning Date
  beg_year <- reactive({
    req(list_year())
    validate(need(list_year(), "Missing time series data, make sure the data has been downloaded properly"))
    min(list_year())
  })
  
  ################################# Take the maximum as ending Date
  end_year <- reactive({
    req(list_year())
    max(list_year())
  })
  
  
  ################################# Take the average date for the beginning and end of historical period
  output$ui_option_h_beg <- renderUI({
    req(input$time_series_dir)
    
    sliderInput(inputId = 'option_h_beg',
                label = textOutput("text_option_h_date_break"),
                min = as.numeric(beg_year()),
                max = as.numeric(end_year()),
                value = as.numeric(beg_year()),
                sep = ""
    )
  })
  
  ################################# Take the average date for the beginning and end of monitoring period
  output$ui_option_m_beg <- renderUI({
    validate(need(input$time_series_dir, "Missing input: Please select time series folder"))
    req(input$option_h_beg)
    
    req(input$time_series_dir)
    sliderInput(inputId = 'option_m_beg',
                label = textOutput("text_option_m_date_break"),
                min = as.numeric(input$option_h_beg),
                max = as.numeric(end_year()),
                value = c((as.numeric(input$option_h_beg) + as.numeric(end_year()))/2,as.numeric(end_year())),
                sep = ""
    )
  })
  
  
  ################################# OPTION ORDER
  output$ui_option_order <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = 'option_order',
                label = "Order parameter",
                choices = 1:5,
                selected = 1
    )
  })
  
  ################################# OPTION HISTORY
  output$ui_option_history <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = 'option_history',
                label = "History parameter",
                choices = c("ROC", "BP", "all",as.numeric(beg_year())),
                selected = "ROC"
    )
  })
  
  ################################# OPTION TYPE
  output$ui_option_type <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = 'option_type',
                label = "Type parameter",
                choices = c("OLS-CUSUM", "OLS-MOSUM", "RE", "ME","fluctuation"),
                selected = "OLS-CUSUM"
    )
  })
  
  ################################# OPTION FORMULA
  output$ui_option_formula <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = 'option_formula',
                label = "Elements of the formula",
                choices = c("harmon","trend"),
                multiple = TRUE,
                selected = "harmon"
    )
  })
  
  ################################# OPTION LAYERS
  output$ui_option_returnLayers <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = 'option_returnLayers',
                label = "Raster band outputs",
                choices = c("breakpoint", "magnitude", "error", "history", "r.squared", "adj.r.squared", "coefficients"),
                multiple = TRUE,
                selected = c("breakpoint", "magnitude", "error")
    )
  })
  
  ################################# OPTION MODE
  output$ui_option_sequential <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = "option_sequential",
                label = "Computation mode",
                choices = c("Overall","Sequential"),
                selected= "Overall"
    )
  })
  
  ################################# OPTION MASK
  output$ui_option_useMask <- renderUI({
    req(input$time_series_dir)
    # req(input$mask_file)
    selectInput(inputId = "option_useMask",
                label = "Use a Forest/Non-Forest mask? (Optional)",
                choices = c("No Mask","FNF Mask"),#,"Sequential"),
                selected= "No Mask"
    )
  })
  
  ################################# OPTION TILES
  output$ui_tiles <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = "option_tiles",
                label = "Which folders do you want to process?",
                choices = basename(list.dirs(data_dir(),recursive = F)),
                selected= basename(list.dirs(data_dir(),recursive = F)),
                multiple = TRUE
    )
  })
  
  ################################# OPTION CHUNK SIZE
  output$ui_option_chunk <- renderUI({
    req(input$time_series_dir)
    selectInput(inputId = "option_chunk",
                label = "Processing chunk size",
                choices = c(128,256,512,1024),#,"Sequential"),
                selected= 512
    )
  })
  
  
  ##################################################################################################################################
  ############### Parameters title as a reactive
  parameters <- reactive({
    req(input$time_series_dir)
    req(input$bfastStartButton)
    
    data_dir            <- paste0(data_dir(),"/")
    
    historical_year_beg <- as.numeric(input$option_h_beg)
    monitoring_year_beg <- as.numeric(input$option_m_beg)[1]
    monitoring_year_end <- as.numeric(input$option_m_beg)[2]
    
    order               <- as.numeric(input$option_order)
    history             <- as.character(input$option_history)
    mode                <- as.character(input$option_sequential)
    type                <- as.character(input$option_type)
    mask                <- as.character(input$option_useMask)
    formula_elements    <- unlist(input$option_formula)
    returnLayers        <- c(as.character(input$option_returnLayers))
    
    #chunk_size          <- as.numeric(input$option_chunk)
    
    type_num            <- c("OC","OM","R","M","f")[which(c("OLS-CUSUM", "OLS-MOSUM", "RE", "ME","fluctuation")==type)]
    mask_opt            <- c("","_msk")[which(c("No Mask","FNF Mask")==mask)]
    formula             <- paste0("response ~ ",paste(formula_elements,sep = " " ,collapse = "+"))
    
    if(input$option_useMask == "FNF Mask"){
      mask_file_path      <- mask_file_path()
    }else{ mask_file_path      <- ""}

    title <- paste0("O_",order,
                    "_H_",paste0(history,collapse = "-"),
                    "_T_",type_num,
                    "_F_",paste0(substr(formula_elements,1,1),collapse= ""),
                    mask_opt,'_',
                    mode,'_',
                    #chunk_size,'_',
                    historical_year_beg,'_',monitoring_year_beg,'_',monitoring_year_end)
    
    
    tiles <- input$option_tiles
    
    rootdir    <- paste0(path.expand("~"),"/")
    username   <- unlist(strsplit(rootdir,"/"))[3]
    res_dir    <- paste0(rootdir,'bfast_results/',basename(data_dir),"_",username,"_PARAM_",title,"/")
    
    dir.create(res_dir,recursive = T,showWarnings = F)
    
    save(rootdir,data_dir,res_dir,historical_year_beg,monitoring_year_end,monitoring_year_beg,order,history,mode,
         #chunk_size,
         type,formula_elements,type_num,formula,title,tiles,mask,mask_opt,mask_file_path,returnLayers,
         file = paste0(res_dir,"my_work_space.RData"))
    
    title
  })
  
  ##################################################################################################################################
  ############### Result storage directory name as a reactive
  res_dir <- reactive({
    req(data_dir())
    req(parameters())
    
    rootdir    <- paste0(path.expand("~"),"/")
    username   <- unlist(strsplit(rootdir,"/"))[3]
    
    data_dir   <- paste0(data_dir(),"/")
    title      <- parameters()
    res_dir    <- paste0(rootdir,'bfast_results/',basename(data_dir),"_",username,"_PARAM_",title,"/")
  })
  
  
  
  ##################################################################################################################################
  ############### Insert the start button
  output$StartButton <- renderUI({
    req(input$time_series_dir)
    validate(need(input$option_tiles, "Missing input: Please select at least one folder to process"))
    validate(need(input$option_formula, "Missing input: Please select at least one element in the formula"))
    validate(need(input$option_returnLayers, "Missing input: Please select at least one layer to export"))
    
    actionButton('bfastStartButton', textOutput('start_button'))
  })
  
  
  ##################################################################################################################################
  ############### Insert the display button only if in OVERALL mode
  output$DisplayButtonCurrent <- renderUI({
    req(input$time_series_dir)
    req(input$bfastStartButton)
    req(mode() == "Overall")
    
    validate(need(input$option_tiles, "Missing input: Please select at least one folder to process"))
    validate(need(input$option_formula, "Missing input: Please select at least one element in the formula"))
    validate(need(input$option_returnLayers, "Missing input: Please select at least one layer to export"))
    
    actionButton('bfastDisplayButton_c', textOutput('display_button_c'))
  })
  
  ##################################################################################################################################
  ############### Insert the display button
  output$DisplayButtonAvailable <- renderUI({
    actionButton('bfastDisplayButton_a', textOutput('display_button_a'))
  })
  
  ##################################################################################################################################
  ############### Insert the refresh button
  output$RefreshButton <- renderUI({
    actionButton('refresh_a', textOutput('text_refresh_a'))
  })
  ##################################################################################################################################
  ############### Set the progress file as a reactive of the parameters
  progress_file <- reactive({
    req(input$time_series_dir)
    req(parameters())

    paste0(res_dir(),"processing_",parameters(),".txt")
  })
  

  ##################################################################################################################################
  ############### SET A REACTIVE VARIABLE TO MONITOR STATUS
  dis_result <- reactiveValues()
  
  mode <- reactive({
    req(input$time_series_dir)
    as.character(input$option_sequential)
  })
  
  ##################################################################################################################################
  ############### Run BFAST
  bfast_res <- eventReactive(input$bfastStartButton,
                             {
                               req(input$time_series_dir)
                               req(input$bfastStartButton)
                               
                               data_dir      <- paste0(data_dir(),"/")
                               res_dir       <- paste0(res_dir(),"/")
                               
                               progress_file <- progress_file()
                               parameters    <- parameters()
                               
                               system(paste0('echo "Preparing data..." > ', progress_file))
                               
                               system(paste0("nohup Rscript www/scripts/bfast_run_nochunk.R ",data_dir,' ',progress_file,' ',res_dir,' & '))
                               #system(paste0("nohup Rscript www/scripts/bfast_run_chunks_warp.R ",data_dir,' ',progress_file,' ',res_dir,' & '))
                               #system(paste0("nohup Rscript www/scripts/bfast_run_chunks_translate.R ",data_dir,' & '))
                               
                               print("done")
                             })
  
  #############################################################
  # Progress monitor function
  output$print_PROGRESS = renderText({
    invalidateLater(1000)
    req(bfast_res())
    
    progress_file <- progress_file()
    
    if(file.exists(progress_file)){
      NLI <- as.integer(system2("wc", args = c("-l", progress_file," | awk '{print $1}'"), stdout = TRUE))
      NLI <- NLI + 1 
      invalidateLater(1000)
      paste(readLines(progress_file, n = NLI, warn = FALSE), collapse = "\n")
    }
    else{
      invalidateLater(2001)
    }
    
  })
  

  
  #############################################################
  ## list of available results to display
  available_results <- eventReactive(input$refresh_a,{
    list.files(path= paste0(paste0(path.expand("~"),"/"),'bfast_results/'), pattern = "_threshold.vrt$", recursive = TRUE)
  })
  

    
  ################################# LIST OF AVAILABLE RESULTS
  output$list_thres <- renderUI({
    fullpaths        <- available_results()
    names(fullpaths) <- basename(available_results())
    
    selectInput(inputId = "results_thres",
                label = "List of processed folders",
                choices = fullpaths
                )
  })
  
  ################################# CHECK AVAILABLE RESULTS 
  observeEvent(input$bfastDisplayButton_a, {
    dis_result$a <- paste0(paste0(path.expand("~"),"/"),'bfast_results/',input$results_thres)
  })
  
  
  ################################# DISPLAY THIS SESSION RESULTS BUTTON
  observeEvent(input$bfastDisplayButton_c, {
    req(bfast_res())

    res_dir <- res_dir()
    
    load(paste0(res_dir(),"/my_work_space.RData"))
    
    if(mode == "Overall"){       dis_result$c <- paste0(res_dir,"results_",title,"_threshold.tif")}
    if(mode == "Sequential"){    dis_result$c <- NULL}
    
  })
  
  ############### Display the CURRENT results as map
  output$display_res  <-  renderLeaflet({

    #req(input$time_series_dir)

    req(bfast_res())
    print('Check: Display the map')
    if (is.null(dis_result$c)) return()
    
    print(dis_result$c)
    
    ############### READ THE RESULT AS RASTER-FACTOR
    rf <- as.factor(raster(dis_result$c))
    
    print(rf)
    print(levels(rf))
    
    lab <- factor(c("Nodata","No change",
                    "Small negative","Medium negative","Large negative","Very large negative",
                    "Small positive","Medium positive","Large positive","Very large positive"))
    
    colorspal <- factor(c("#000000","#fdfdfd",
                          "#f8ffa3","#fdc980","#e31a1c","#a51013",
                          "#c3e586","#96d165","#58b353","#1a9641"))
    
    pal <- colorNumeric(c("#000000","#fdfdfd",
                          "#f8ffa3","#fdc980","#e31a1c","#a51013",
                          "#c3e586","#96d165","#58b353","#1a9641"), 
                        c(0,values(rf)),
                        na.color = "transparent")
    
    m <- leaflet() %>% addTiles() %>%
      addProviderTiles('Esri.WorldImagery') %>% 
      
      addProviderTiles("CartoDB.PositronOnlyLabels")%>% 
      
      addRasterImage(rf, colors = pal, opacity = 0.8, group='Results') %>%
      ## LEGEND is not working -- to be fixed
      # addLegend(colors=colorspal,
      #           values = values(rf),
      #           title = "BFAST results"
      #           ,labels= lab) %>% 
      
      addLayersControl(
        overlayGroups = c("Results"),
        options = layersControlOptions(collapsed = FALSE)
      )  
    
  })
  
  
  ############### Display the AVAILABLE results as map
  output$display_available_res <-  renderLeaflet({
    req(input$bfastDisplayButton_a)

    print('Check: Display the map')
    if (is.null(dis_result$a)) return()
    
    print(dis_result$a)
    
    ############### READ THE RESULT AS RASTER-FACTOR
    rf <- as.factor(raster(dis_result$a))
    
    print(rf)
    print(levels(rf))
    
    lab <- factor(c("Nodata","No change",
                    "Small negative","Medium negative","Large negative","Very large negative",
                    "Small positive","Medium positive","Large positive","Very large positive"))
    
    colorspal <- factor(c("#000000","#fdfdfd",
                          "#f8ffa3","#fdc980","#e31a1c","#a51013",
                          "#c3e586","#96d165","#58b353","#1a9641"))
    
    pal <- colorNumeric(c("#000000","#fdfdfd",
                          "#f8ffa3","#fdc980","#e31a1c","#a51013",
                          "#c3e586","#96d165","#58b353","#1a9641"), 
                        c(0,values(rf)),
                        na.color = "transparent")
    
    m <- leaflet() %>% addTiles() %>%
      addProviderTiles('Esri.WorldImagery') %>% 
      
      addProviderTiles("CartoDB.PositronOnlyLabels")%>% 
      
      addRasterImage(rf, colors = pal, opacity = 0.8, group='Results') %>%
      
      addLegend(colors=colorspal,
                values = values(rf),
                title = "BFAST results"
                ,labels= lab) %>% 
      
      addLayersControl(
        overlayGroups = c("Results"),
        options = layersControlOptions(collapsed = FALSE)
      )  
    
  })
  
  ##################################################################################################################################
  ############### Display parameters
  output$parameterSummary <- renderText({
    req(input$time_series_dir)
    print(paste0("Parameters are : ",parameters()))
  })
  
  ##################################################################################################################################
  ############### Display parameters
  # You can access the value of the widget with input$num, e.g.
  output$num_class <- renderPrint({ input$num_class })
  
  
  ##################################################################################################################################
  ############### Processing time as reactive
  process_time <- reactive({
    req(bfast_res())
    # 
    #     log_filename <- list.files(data_dir(),pattern="log",recursive = T)[1]
    #     print(paste0(data_dir(),"/",log_filename))
    #     readLines(paste0(data_dir(),"/",log_filename))
  })
  
  ##################################################################################################################################
  ############### Display time
  output$message <- renderText({
    #req(bfast_res())
    # print("processing time")
    # process_time()
  })
  
  ##################################################################################################################################
  ############### Turn off progress bar
  
  progress$close()
  ################## Stop the shiny server
  ####################################################################################
  
})
