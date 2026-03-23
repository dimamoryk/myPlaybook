#!/bin/bash

# Строим проект с помощью Maven
mvn clean install

# Запускаем проект
mvn spring-boot:run