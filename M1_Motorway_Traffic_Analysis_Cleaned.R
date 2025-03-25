# Cleaned and formatted R script for M1 Motorway Traffic Analysis

# The full code would go here...
# ============================================================================
# Package Installation and Loading
# ============================================================================

# Install required packages (run once)
install.packages(c("readxl", "dplyr", "openxlsx", "psych", "naniar", "tidyr",
                   "ggplot2", "ggcorrplot", "corrplot", "ggjoy"))

# Load libraries for data manipulation
library(readxl)    # For reading Excel files
library(dplyr)     # For data manipulation
library(openxlsx)  # For Excel file operations
library(psych)     # For descriptive statistics
library(naniar)    # For missing data visualization
library(tidyr)     # For data tidying

# Load libraries for data visualization
library(ggplot2)    # For plotting
library(ggcorrplot) # For correlation plots
library(corrplot)   # For correlation matrices
library(ggjoy)      # For joy plots (though not used here)

# ============================================================================
# Data Import and Initial Processing
# ============================================================================

# List of dates for file names
dates <- c(paste0("March", 20:31), paste0("April", 1:9))

# Import all Excel files into a list and combine into a single dataframe
dataset <- lapply(dates, function(date) {
  read_excel(paste0(date, ".xlsx"))
}) %>% bind_rows()

# Check dimensions and describe the dataset
dim(dataset)
describe(dataset)  # Note: 'traffic_data' was used prematurely earlier; corrected to 'dataset'

# Select relevant columns (27 out of 332)
traffic_data <- dataset[, c(1, 2, 4, 25, 56, 72, 109, 126, 204, 60, 76, 113, 130, 
                            208, 234, 39, 86, 123, 88, 89, 17, 22, 48, 53, 106, 
                            196, 201)]

# Rename columns for clarity
new_colnames <- c("Date", "Daytime", "Junction", "Length_PDJ0", "Length_SUJ0", 
                  "Length_SUJ1", "Length_PUJ0", "Length_PUJ1", "Length_SDJ0", 
                  "LinkName_SUJ0", "LinkName_SUJ1", "LinkName_PUJ0", "LinkName_PDJ1", 
                  "LinkName_SDJ0", "Speed_SDJ", "Speed_PDJ", "Speed_SUJ", "Speed_PUJ", 
                  "Primary_Location", "Secondary_Location", "PdDestinationDS", 
                  "PdDestinationUS", "SuDestinationDS", "SuDestinationUS", 
                  "PuDestinationUS", "SdDestinationDS", "SdDestinationUS")
colnames(traffic_data) <- new_colnames

# Add Weekday column based on Date
traffic_data <- traffic_data %>%
  mutate(Weekday = weekdays(Date)) %>%
  select(Date, Weekday, everything())  # Reorder columns with Date and Weekday first

# Quick inspection
glimpse(traffic_data)
dim(traffic_data)

# ============================================================================
# Data Cleaning
# ============================================================================

# Check for duplicates and missing values
sum(duplicated(traffic_data))  # No duplicates expected
sum(is.na(traffic_data))       # Total missing values
vis_miss(traffic_data)         # Visualize missingness

# Impute missing numeric values with median
numeric_cols <- c("Length_PDJ0", "Length_SUJ0", "Length_SUJ1", "Length_PUJ0", 
                  "Length_PUJ1", "Length_SDJ0", "Speed_SDJ", "Speed_PDJ", 
                  "Speed_SUJ", "Speed_PUJ")
for (col in numeric_cols) {
  median_val <- median(traffic_data[[col]], na.rm = TRUE)
  traffic_data[[col]] <- ifelse(is.na(traffic_data[[col]]), median_val, traffic_data[[col]])
}

# Handle missing Date and Weekday specifically
traffic_data$Date[is.na(traffic_data$Date)] <- "2023-03-21"
traffic_data$Weekday[is.na(traffic_data$Weekday)] <- "Tuesday"

# Replace remaining NA with "Unknown" for non-numeric columns
traffic_data <- traffic_data %>%
  mutate_all(~ifelse(is.na(.), "Unknown", .))

# Convert Date to proper date format
traffic_data <- traffic_data %>%
  mutate(Date = as.Date(Date))

# Verify no missing values remain
sum(is.na(traffic_data))

# Convert categorical variables to factors
factor_cols <- c("Weekday", "Daytime", "Junction", "Primary_Location", 
                 "Secondary_Location", "PdDestinationDS", "PdDestinationUS", 
                 "SuDestinationDS", "SuDestinationUS", "PuDestinationUS", 
                 "SdDestinationDS", "SdDestinationUS")
traffic_data[factor_cols] <- lapply(traffic_data[factor_cols], as.factor)

# Order Weekday factor
traffic_data$Weekday <- factor(traffic_data$Weekday, 
                               levels = c("Monday", "Tuesday", "Wednesday", "Thursday", 
                                          "Friday", "Saturday", "Sunday"), ordered = TRUE)

# ============================================================================
# Descriptive Statistics
# ============================================================================

# Summary of numeric variables
summary(traffic_data[numeric_cols])

# ============================================================================
# Exploratory Data Analysis (EDA)
# ============================================================================

# Correlation matrix for all numeric variables
corr_all <- cor(traffic_data[numeric_cols])
corrplot(corr_all, method = "color", type = "upper", order = "hclust", 
         col = colorRampPalette(c("white", "red"))(100), tl.col = "black", 
         tl.srt = 45, addCoef.col = "black", diag = FALSE, 
         title = "Correlation Matrix of Traffic Data")

# Correlation matrix for speeds only
corr_speeds <- cor(traffic_data[c("Speed_SDJ", "Speed_PDJ", "Speed_SUJ", "Speed_PUJ")])
corrplot(corr_speeds, method = "color", type = "upper", order = "hclust", 
         col = colorRampPalette(c("white", "red"))(100), tl.col = "black", 
         tl.srt = 45, addCoef.col = "black", diag = FALSE, 
         title = "Correlation Matrix of Average Speeds")

# Function to create boxplots
create_boxplot <- function(data, y_var, title, y_label) {
  ggplot(data, aes(x = "", y = .data[[y_var]])) +
    geom_boxplot(fill = "magenta", color = "grey4", alpha = 0.8) +
    labs(x = "", y = y_label, title = title) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(),
          panel.border = element_blank(),
          axis.line = element_line(colour = "black"),
          axis.text.x = element_blank())
}

# Boxplots for road lengths
length_vars <- c("Length_PDJ0", "Length_SUJ0", "Length_SUJ1", "Length_PUJ0", 
                 "Length_PUJ1", "Length_SDJ0")
length_titles <- c("Northbound Downstream Link 0 Distance", "Southbound Upstream Link 0 Distance", 
                   "Southbound Upstream Link 1 Distance", "Northbound Upstream Link 0 Distance", 
                   "Northbound Upstream Link 1 Distance", "Southbound Downstream Link 0 Distance")
for (i in seq_along(length_vars)) {
  print(create_boxplot(traffic_data, length_vars[i], length_titles[i], "Distance of Road"))
}

# Boxplots for speeds
speed_vars <- c("Speed_SDJ", "Speed_PDJ", "Speed_SUJ", "Speed_PUJ")
speed_titles <- c("Average Speed Along Southbound Downstream", "Average Speed Along Northbound Downstream", 
                  "Average Speed Along Southbound Upstream", "Average Speed Along Northbound Upstream")
for (i in seq_along(speed_vars)) {
  print(create_boxplot(traffic_data, speed_vars[i], speed_titles[i], "Average Speed (mph)"))
}

# Function to create histograms
create_histogram <- function(data, x_var, title, x_label, binwidth = 500) {
  ggplot(data, aes(x = .data[[x_var]])) +
    geom_histogram(fill = "slateblue1", color = "black", binwidth = binwidth) +
    labs(x = x_label, y = "Count", title = title)
}

# Histograms for road lengths
for (i in seq_along(length_vars)) {
  print(create_histogram(traffic_data, length_vars[i], paste("Distribution of", length_titles[i]), "Road Length"))
}

# Histograms for speeds (no binwidth specified for speed to allow default)
for (i in seq_along(speed_vars)) {
  print(create_histogram(traffic_data, speed_vars[i], paste("Distribution of", speed_titles[i]), "Speed (mph)", NULL))
}

# ============================================================================
# Sampling and Speed Analysis
# ============================================================================

# Sampling by Weekday
set.seed(42)  # For reproducibility
sampled_day <- traffic_data %>%
  group_by(Weekday) %>%
  sample_n(size = 50, replace = FALSE) %>%
  ungroup()

# Check sampled data
dim(sampled_day)
table(sampled_day$Weekday)

# Boxplots for speed by weekday
for (var in speed_vars) {
  title <- paste("Variations in Speed by Weekday along", gsub("Speed_", "", var))
  print(ggplot(sampled_day, aes(x = Weekday, y = .data[[var]], fill = Weekday)) +
          geom_boxplot() +
          scale_fill_brewer(palette = "Set1") +
          labs(title = title, x = "Weekdays", y = "Speed (mph)") +
          theme(axis.text.x = element_text(angle = 90, vjust = 0.5)))
}

# Sampling by Daytime
set.seed(42)
sampled_daytime <- traffic_data %>%
  group_by(Daytime) %>%
  sample_n(size = 116, replace = FALSE) %>%
  ungroup() %>%
  mutate(Daytime = factor(Daytime, levels = c("Morning", "Afternoon", "Night"), ordered = TRUE))

# Check sampled data
dim(sampled_daytime)
table(sampled_daytime$Daytime)

# Boxplots for speed by daytime
for (var in speed_vars) {
  title <- paste("Variations in Speed by Daytime along", gsub("Speed_", "", var))
  print(ggplot(sampled_daytime, aes(x = Daytime, y = .data[[var]], fill = Daytime)) +
          geom_boxplot() +
          scale_fill_brewer(palette = "Set1") +
          labs(title = title, x = "Daytime", y = "Speed (mph)") +
          theme(axis.text.x = element_text(angle = 90, vjust = 0.5)))
}

# Add Day_Type column (Weekday vs Weekend)
traffic_data <- traffic_data %>%
  mutate(Day_Type = ifelse(Weekday %in% c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"), 
                           "Weekday", "Weekend"))

# Sampling by Day Type
set.seed(42)
sampled_daytype <- traffic_data %>%
  group_by(Weekday) %>%
  sample_n(size = 51, replace = FALSE) %>%
  ungroup() %>%
  mutate(Day_Type = factor(Day_Type, levels = c("Weekday", "Weekend"), ordered = TRUE))

# Check sampled data
dim(sampled_daytype)
table(sampled_daytype$Day_Type)

# Boxplots for speed by day type
for (var in speed_vars) {
  title <- paste("Variations in Speed by Day Type along", gsub("Speed_", "", var))
  print(ggplot(sampled_daytype, aes(x = Day_Type, y = .data[[var]], fill = Day_Type)) +
          geom_boxplot() +
          scale_fill_brewer(palette = "Set1") +
          labs(title = title, x = "Day Type", y = "Speed (mph)") +
          theme(axis.text.x = element_text(angle = 90, vjust = 0.5)))
}

# ============================================================================
# Speed by Location
# ============================================================================

# Aggregate speed by Primary Location (Northbound)
agg_data_north <- traffic_data %>%
  group_by(Primary_Location) %>%
  summarise(Speed_PUJ_mean = mean(Speed_PUJ, na.rm = TRUE)) %>%
  ungroup()

ggplot(agg_data_north, aes(x = Primary_Location, y = Speed_PUJ_mean)) +
  geom_bar(stat = "identity", fill = "darkorchid2") +
  labs(title = "Average Speed along Northbound City Sections", x = "City Section", y = "Average Speed (mph)") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5))

# Aggregate speed by Secondary Location (Southbound)
agg_data_south <- traffic_data %>%
  group_by(Secondary_Location) %>%
  summarise(Speed_SDJ_mean = mean(Speed_SDJ, na.rm = TRUE)) %>%
  ungroup()

ggplot(agg_data_south, aes(x = Secondary_Location, y = Speed_SDJ_mean)) +
  geom_bar(stat = "identity", fill = "darkorchid2") +
  labs(title = "Average Speed along Southbound City Sections", x = "City Section", y = "Average Speed (mph)") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5))

# ============================================================================
# Scatter Plots
# ============================================================================

# Scatter plots by Day Type
scatter_pairs <- list(c("Speed_SDJ", "Speed_PDJ", "Northbound and Southbound Downstream"),
                      c("Speed_PUJ", "Speed_SUJ", "Northbound and Southbound Upstream"),
                      c("Speed_PDJ", "Speed_PUJ", "Northbound Upstream and Downstream"),
                      c("Speed_SDJ", "Speed_SUJ", "Southbound Upstream and Downstream"))

for (pair in scatter_pairs) {
  print(ggplot(sampled_daytype, aes(x = .data[[pair[1]]], y = .data[[pair[2]]], color = Day_Type)) +
          geom_point() +
          scale_color_brewer(palette = "Set1") +
          labs(title = paste("Relationship between", pair[3], "Speeds by Day Type"),
               x = paste(gsub("Speed_", "", pair[1]), "Speed (mph)"),
               y = paste(gsub("Speed_", "", pair[2]), "Speed (mph)")))
}

# Scatter plots by Weekday
for (pair in scatter_pairs) {
  print(ggplot(sampled_day, aes(x = .data[[pair[1]]], y = .data[[pair[2]]], color = Weekday)) +
          geom_point() +
          scale_color_brewer(palette = "Set1") +
          labs(title = paste("Relationship between", pair[3], "Speeds by Weekdays"),
               x = paste(gsub("Speed_", "", pair[1]), "Speed (mph)"),
               y = paste(gsub("Speed_", "", pair[2]), "Speed (mph)")))
}

# ============================================================================
# Sampling by Date
# ============================================================================

# Add Date_ID for sampling
traffic_data <- traffic_data %>%
  mutate(Date_ID = as.integer(as.Date(Date) - as.Date("2023-03-20")))

# Sample by Date (357 total, 17 per day)
set.seed(42)
sampled_date <- traffic_data %>%
  group_by(Date_ID) %>%
  filter(n() >= 17) %>%
  sample_n(17, replace = FALSE) %>%
  ungroup()

# Convert Date to factor for plotting
sampled_date$Date <- factor(sampled_date$Date)

# Boxplots for speed by date
for (var in speed_vars) {
  title <- paste("Distribution of Speed by Date along", gsub("Speed_", "", var))
  print(ggplot(sampled_date, aes(x = Date, y = .data[[var]], fill = Date)) +
          geom_boxplot() +
          scale_fill_manual(values = rainbow(length(unique(sampled_date$Date)))) +
          labs(title = title, x = "Date", y = "Speed (mph)") +
          theme(axis.text.x = element_text(angle = 90, hjust = 1)))
}