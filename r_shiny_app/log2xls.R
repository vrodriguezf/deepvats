file_path = "witc2024"
data <- readLines(file_path)

processed_data <- gsub("::::", "|", data)
processed_data <- gsub(":", "|", processed_data)
processed_data <- gsub("\\|", ";", processed_data)

library(stringr)

split_data <- str_split(processed_data, ";", simplify = TRUE)
df <- as.data.frame(split_data)

# Mostrar el DataFrame
print(df)