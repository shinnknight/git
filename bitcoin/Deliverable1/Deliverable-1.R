#load library
library(readxl)
library(stringr)
library(ggplot2)
library(lubridate)
library(data.table)
library(dplyr)

#read data in to workplce
data <- read_xlsx("./bitcoin_price_v3.xlsx",sheet = "2011.9.13-2017.10.8")
View(data)
str(data)
summary(data)

# detect NA
sum(which(is.na(data)))

# count number of '-' in each column
str_count(data[,2:ncol(data)], fixed("—"))

# Delete rows containing "—" , because only 21 rows contain that.
x<-which(data[,2:ncol(data)]=='—', arr.ind=TRUE)
y<-unique(x[,1])
data <- data[-y,]

#test is there any -
str_count(data[,2:8], fixed("—"))

#There are spaces on the both sides of timestamp, we need to remove spaces first.
str_trim(data$Timestamp,side='both')

#Create a line chart to show how Close price changed over time.
graphics::plot(data = data, Close~Timestamp ,type="l")



#we add Year, Month and Day as new variables to the dataset
datesplit <- unlist(strsplit(as.character(data$Timestamp), "-", fixed = TRUE))
datesplit <- split(datesplit, 1:3)
Month <- datesplit$`2`
Day <- datesplit$`3`
Year <- datesplit$`1`
data <- cbind(Year,Month,Day,data)
attach(data)

#see the mean Close price of each year
barplot(by(as.numeric(data$Close),factor(data$Year),mean))

#Add new variable named DailyChangeRate, which means the variation between Close price and Open price. The formula is DailyChange=(Close price-Open price)/Open price
Close <- as.numeric(Close)
Open <- as.numeric(Open)
DailyChangeRate <- (Close - Open)/Open
DailyChangeRate <- round(DailyChangeRate,digits = 4)

#Add this new variable to dataset and name the new dataset as data_update
data <- cbind(data,DailyChangeRate)
attach(data)
boxplot(DailyChangeRate,ylim = c(-0.8,0.8))

breaks <- seq(-0.5,0.6, by = 0.1)
dat2 <- cut(data$DailyChangeRate, breaks = breaks)
table(dat2)
barplot(table(dat2))
hist(x=DailyChangeRate)
rug(DailyChangeRate)

#Create a histogram to show the variation between Close price and Open price 
barplot(DailyChangeRate, ylim = c(-0.6,  0.6))

#We consider time as a predictor variable to predict Close price. 
Year <- as.numeric(Year)
model = lm(Close~ log(Year))
coef(model)
plot(Close ~ Year)
abline(model)
residuals(model)

#log days and price from 2011.9.1
start_date <- as.POSIXct("01-01-2011", format = "%d-%m-%Y", tz = "UTC")
span <- data$Timestamp - start_date
span <- day(days(span))
data <- cbind(data,span)

par(mfrow=c(2,2))
daymodel <- lm(Close ~ log(data$span))
coef(daymodel)
plot(daymodel)

par(mfrow=c(1,1))

#Read new datasets
data_Gold <- read_xlsx("./bitcoin_price_v3.xlsx",sheet = "Gold")

#rename column names because new dataset has the same column names as the original dataset. For instance, they both use "Close" as their close price. We need to distinguish which is the closing price of the bitcoin and which is the closing price of gold

names(data_Gold) <- c("Timestamp","GoldClose","GlodOpen","GoldHigh","GoldLow","GoldVolume","GoldRatio")

data_Oil <- read_xlsx("./bitcoin_price_v3.xlsx",sheet = "WTI Oil")
names(data_Oil) <- c("Timestamp","OilClose","OilOpen","OilHigh","OilLow","OilVolume","OilRatio")

data_Gas <- read_xlsx("./bitcoin_price_v3.xlsx",sheet = "Gas")
names(data_Gas) <- c("Timestamp","GasClose","GasOpen","GasHigh","GasLow","GasVolume","GasRatio")

data <- data.table(data)
gastable <- data.table(data_Gas)
goldtable <- data.table(data_Gold)
oiltable <- data.table(data_Oil)

commodity <- full_join(data,gastable,by="Timestamp")
commodity <- full_join(commodity,goldtable,by="Timestamp")
commodity <- full_join(commodity,oiltable,by="Timestamp")

commodity <- na.omit(commodity)

#Identify location of missing values i.e. sum NAs
sum(which(is.na(commodity)))


str(commodity)
commodity$Close <- as.numeric(commodity$Close)
attach(commodity)
#we use the lm() function to perform linear regression with the formula Close ~ GoldClose. 

Modelgold <- lm(commodity$Close ~ commodity$GoldClose)
coef(Modelgold)
summary(Modelgold)

Modeloil <- lm(commodity$Close ~ commodity$OilClose)
coef(Modeloil)
summary(Modeloil)

Modelgas <- lm(commodity$Close ~ commodity$GasClose)
coef(Modelgas)
summary(Modelgas)

#visualize this linear relationship between GoldClose and Close as a line on the scatter plot between these two variables.
par(mfrow=c(2,2))

plot(commodity$GoldClose,commodity$Close,xlab = 'Gold',ylab = 'Bitcoin')
abline(Modelgold,col='red')

#we use the lm() function to perform linear regression with the formula Close ~ GasClose. 

plot(commodity$OilClose,commodity$Close,xlab = 'Oil',ylab = 'Bitcoin')
abline(Modeloil,col='red')

plot(commodity$GasClose,commodity$Close,xlab = 'Gas',ylab = 'Bitcoin')
abline(Modelgas,col='red')

#log-linear regression and visualize
Modellog <- lm(commodity$Close ~ log(commodity$GoldClose))
coef(Modellog)
summary(Modellog)
plot(log(commodity$GoldClose),commodity$Close)
abline(Modellog,col='red')

par(mfrow=c(1,1))

#LOESS model
ModelLOESS<- loess(commodity$Close ~ commodity$GoldClose)
summary(ModelLOESS)
plot(ModelLOESS)

#we use the lm() function to perform Multivariate linear regression with the formula Close ~ OilClose+GoldClose+GasClose. 

Model_multi <- lm(commodity$Close ~ commodity$OilClose+commodity$GasClose+commodity$GoldClose)
coef(Model_multi)
summary(Model_multi)


Model_multi <- lm(commodity$Close ~ commodity$OilClose+commodity$GoldClose)
coef(Model_multi)
summary(Model_multi)

#add total volume to this Multivariate linear regression with the formula Close ~ OilClose+GoldClose+GasClose+btc_total_bitcoins

commodity$`Volume (Currency)` <- as.numeric(commodity$`Volume (Currency)`)
plot(commodity$Close ~ commodity$`Volume (Currency)`,xlab = 'Volume' , ylab = 'Price', main='Volumn(Currency) ~ Price')
model_currency <- lm(commodity$Close ~ commodity$`Volume (Currency)`)
summary(model_currency)
abline(model_currency,col='red')

# we try to plot candle graph of the pirce
sz<-data[1:nrow(data),c(1:2,4:8)]
colnames(sz)<-c('year','month','time','open','high','low','close')
sz$id<- c(1:nrow(sz))
sz$open <- as.numeric(sz$open)
sz$high <- as.numeric(sz$high)
sz$low <- as.numeric(sz$low)
sz$close <- as.numeric(sz$close)

sz$candleLower<-pmin(sz$open,sz$close)
sz$candleUpper<-pmax(sz$open,sz$close)
sz$candleMiddle<- (sz$candleLower + sz$candleUpper) /2
sz$color<-"red"
sz$color[sz$close<sz$open]="green"
ggplot(data=sz)+
  geom_boxplot(lwd=0,stat='identity',aes(x=sz$id,lower=sz$candleLower,middle=sz$candleMiddle,upper=sz$candleUpper,ymin=sz$low,ymax=sz$high,group=sz$id,fill=sz$color))+
  scale_fill_manual(values=c('green','red'))+
  guides(fill=FALSE)+
  theme_bw()+
  theme(panel.grid=element_blank(),panel.border=element_blank())

