###################################################################
# API REGON GUS - DaneSzukajPodmioty; pojedyncze i wielorakie rekordy #
###################################################################

library(stringr)
library(readr)
library(httr2)
library(xml2)

# Dane logowania do API BIR  - W przypadku uzyskania Klucza osobistego z każdej instancji poniższego linku usunąć 'test'
BIR_URL <- "https://wyszukiwarkaregontest.stat.gov.pl/wsBIR/UslugaBIRzewnPubl.svc"
USER_KEY <- "abcde12345abcde12345"  # Wpisz tutaj swój klucz API

# Funkcja do logowania się do API BIR
# Parametr debug określa czy wyświetlać szczegółowe informacje
zaloguj <- function(debug = TRUE) {
  # Tworzymy zapytanie SOAP do logowania
  body <- paste0('<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
xmlns:ns="http://CIS/BIR/PUBL/2014/07">
<soap:Header xmlns:wsa="http://www.w3.org/2005/08/addressing">
<wsa:To>https://wyszukiwarkaregontest.stat.gov.pl/wsBIR/UslugaBIRzewnPubl.svc</wsa:To>
<wsa:Action>http://CIS/BIR/PUBL/2014/07/IUslugaBIRzewnPubl/Zaloguj</wsa:Action>
</soap:Header>
 <soap:Body>
 <ns:Zaloguj>
 <ns:pKluczUzytkownika>', USER_KEY, '</ns:pKluczUzytkownika>
 </ns:Zaloguj>
 </soap:Body>
</soap:Envelope>')
  
  # Przygotowanie zapytania HTTP
  req <- request(BIR_URL) |>
    req_method("POST") |>
    req_headers(
      "Content-Type" = "application/soap+xml; charset=utf-8"
    ) |>
    req_body_raw(body)
  
  # Wykonanie zapytania z obsługą błędów
  response <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    message("Błąd podczas zapytania do API: ", e$message)
    return(NULL)
  })
  
  # Sprawdzenie czy zapytanie się powiodło
  if (is.null(response)) {
    message("Logowanie nie powiodło się.")
    return(NULL)
  }
  
  # Wyświetlenie surowej odpowiedzi w trybie debug
  if (debug) {
    print("Surowa odpowiedź:")
    print(resp_body_string(response))
  }
  
  # Wyciągnięcie identyfikatora sesji za pomocą wyrażeń regularnych
  content <- resp_body_string(response)
  sid_pattern <- "<ZalogujResult>(.*?)</ZalogujResult>"
  matches <- regmatches(content, regexec(sid_pattern, content, perl = TRUE))[[1]]
  
  # Sprawdzenie czy udało się znaleźć SID
  if (length(matches) > 1) {
    sid <- matches[2]
    if (!is.na(sid) && sid != "") {
      return(sid)
    }
  }
  
  # Jeśli nie znaleziono SID, próbujemy alternatywnej metody
  message("Błąd: Nie znaleziono identyfikatora sesji. Próbuję alternatywnej metody...")
  
  # Próba bezpośredniego parsowania XML
  tryCatch({
    xml_doc <- read_xml(content)
    sid <- xml_text(xml_find_first(xml_doc, "//ZalogujResult"))
    
    if (!is.na(sid) && sid != "") {
      return(sid)
    }
  }, error = function(e) {
    if (debug) {
      message("Błąd parsowania odpowiedzi jako XML: ", e$message)
    }
  })
  
  # Jeszcze bardziej elastyczne podejście
  message("Próbuję alternatywnej ekstrakcji XML...")
  
  # Bardziej elastyczny wzorzec regex
  xml_pattern <- "<.*?:Envelope.*?</.*?:Envelope>"
  xml_matches <- regmatches(content, regexec(xml_pattern, content, perl = TRUE))[[1]]
  
  # Jeśli udało się wyciągnąć cały XML, próbujemy znaleźć SID
  if (length(xml_matches) > 0 && xml_matches[1] != "") {
    tryCatch({
      xml_doc <- read_xml(xml_matches[1])
      
      # Próba różnych ścieżek XPath do znalezienia wyniku
      xpath_patterns <- c(
        "//ZalogujResult", 
        "//*[local-name()='ZalogujResult']",
        "//*:ZalogujResult"
      )
      
      # Sprawdzamy każdą możliwą ścieżkę XPath
      for (xpath in xpath_patterns) {
        node <- xml_find_first(xml_doc, xpath)
        if (!is.na(node) && !is.null(node)) {
          sid <- xml_text(node)
          if (!is.na(sid) && sid != "") {
            return(sid)
          }
        }
      }
    }, error = function(e) {
      if (debug) {
        message("Błąd w alternatywnej ekstrakcji XML: ", e$message)
      }
    })
  }
  
  # Jeśli wszystkie metody zawiodły
  message("Błąd: Nie udało się uzyskać prawidłowego SID po wypróbowaniu wszystkich metod.")
  return(NULL)
}

# Funkcja do wylogowania się z API BIR
wyloguj <- function(sid) {
  # Przygotowanie zapytania SOAP
  body <- paste0('<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
xmlns:ns="http://CIS/BIR/PUBL/2014/07">
<soap:Header xmlns:wsa="http://www.w3.org/2005/08/addressing">
<wsa:To>https://wyszukiwarkaregontest.stat.gov.pl/wsBIR/UslugaBIRzewnPubl.svc</wsa:To>
<wsa:Action>http://CIS/BIR/PUBL/2014/07/IUslugaBIRzewnPubl/Wyloguj</wsa:Action>
</soap:Header>
 <soap:Body>
 <ns:Wyloguj>
 <ns:pIdentyfikatorSesji>', sid, '</ns:pIdentyfikatorSesji>
 </ns:Wyloguj>
 </soap:Body>
</soap:Envelope>')
  
  # Przygotowanie zapytania HTTP
  req <- request(BIR_URL) |>
    req_method("POST") |>
    req_headers(
      "Content-Type" = "application/soap+xml; charset=utf-8",
      "sid" = sid
    ) |>
    req_body_raw(body)
  
  # Wykonanie zapytania z obsługą błędów
  response <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    message("Błąd podczas wylogowywania: ", e$message)
    return(NULL)
  })
  
  # Sprawdzenie czy zapytanie się powiodło
  if (is.null(response)) {
    message("Wylogowanie nie powiodło się.")
    return(NULL)
  }
  
  return(response)
}

# Logujemy się i zapisujemy identyfikator sesji
sid <- zaloguj()
if (!is.null(sid)) 
  print(paste("Uzyskano SID:", sid))

# Funkcja wyszukująca podmioty gospodarcze w bazie REGON
# Pobiera dane na podstawie różnych identyfikatorów (NIP, REGON, KRS)
search_entities <- function(parameter_value, parameter_name = "Nip", user_key = USER_KEY) {
  # Konstrukcja nagłówka zapytania SOAP
  # Definiujemy przestrzenie nazw i adresy wymagane przez API GUS
  soap_body <- paste0(
    '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" ',
    'xmlns:ns="http://CIS/BIR/PUBL/2014/07" ',
    'xmlns:dat="http://CIS/BIR/PUBL/2014/07/DataContract">',
    '<soap:Header xmlns:wsa="http://www.w3.org/2005/08/addressing">',
    '<wsa:To>https://wyszukiwarkaregontest.stat.gov.pl/wsBIR/UslugaBIRzewnPubl.svc</wsa:To>',
    '<wsa:Action>http://CIS/BIR/PUBL/2014/07/IUslugaBIRzewnPubl/DaneSzukajPodmioty</wsa:Action>',
    '</soap:Header>',
    '<soap:Body>',
    '<ns:DaneSzukajPodmioty>',
    '<ns:pParametryWyszukiwania>'
  )
  
  # Dodajemy odpowiedni tag wyszukiwania zależnie od wybranego parametru
  # API REGON pozwala na wyszukiwanie po różnych identyfikatorach
  if(parameter_name == "Regon") {
    soap_body <- paste0(soap_body, '<dat:Regon>', parameter_value, '</dat:Regon>')
  } else if(parameter_name == "Nip") {
    soap_body <- paste0(soap_body, '<dat:Nip>', parameter_value, '</dat:Nip>')
  } else if(parameter_name == "Krs") {
    soap_body <- paste0(soap_body, '<dat:Krs>', parameter_value, '</dat:Krs>')
  } else if(parameter_name == "Nipy") {
    soap_body <- paste0(soap_body, '<dat:Nipy>', parameter_value, '</dat:Nipy>')
  } else if(parameter_name == "Regony9zn") {
    soap_body <- paste0(soap_body, '<dat:Regony9zn>', parameter_value, '</dat:Regony9zn>')
  } else if(parameter_name == "Krsy") {
    soap_body <- paste0(soap_body, '<dat:Krsy>', parameter_value, '</dat:Krsy>')
  } else if(parameter_name == "Regony14zn") {
    soap_body <- paste0(soap_body, '<dat:Regony14zn>', parameter_value, '</dat:Regony14zn>')
  }
  
  # Zamykamy zapytanie SOAP odpowiednimi tagami
  soap_body <- paste0(
    soap_body,
    '</ns:pParametryWyszukiwania>',
    '</ns:DaneSzukajPodmioty>',
    '</soap:Body>',
    '</soap:Envelope>'
  )
  
  # Przygotowanie żądania HTTP
  # Używamy biblioteki httr do wykonania zapytania POST
  req <- request("https://wyszukiwarkaregontest.stat.gov.pl/wsBIR/UslugaBIRzewnPubl.svc") %>%
    req_method("POST") %>%
    req_headers(
      "Content-Type" = "application/soap+xml;charset=UTF-8",
      "SOAPAction" = "http://CIS/BIR/PUBL/2014/07/IUslugaBIRzewnPubl/DaneSzukajPodmioty",
      "User-Key" = user_key
    )
  
  # Dodajemy identyfikator sesji, jeśli istnieje
  # Sesja może być potrzebna do kontynuacji komunikacji z serwisem
  if(exists("sid") && !is.null(sid)) {
    req <- req %>% req_headers("sid" = sid)
  }
  
  # Wysyłamy zapytanie i odbieramy odpowiedź
  req <- req %>% req_body_raw(soap_body)
  resp <- req_perform(req)
  
  return(resp)
}


# Funkcja parsująca wyniki wyszukiwania z odpowiedzi SOAP
# Przekształca XML na strukturę danych R
parse_search_results <- function(response) {
  # Pobieramy treść odpowiedzi jako tekst
  if(is.character(response)) {
    response_text <- response
  } else {
    response_text <- resp_body_string(response)
  }
  
  # Wyciągamy właściwą część XML (usuwamy nagłówki SOAP)
  # Szukamy bloku z danymi wynikowymi
  xml_content <- gsub(".*?<DaneSzukajPodmiotyResult>(.*?)</DaneSzukajPodmiotyResult>.*", "\\1", response_text, perl = TRUE)
  
  # Zamieniamy znaki specjalne XML na ich faktyczne odpowiedniki
  xml_content <- gsub("&lt;", "<", xml_content)
  xml_content <- gsub("&gt;", ">", xml_content)
  xml_content <- gsub("&#xD;", "", xml_content) # Usuwamy znaki powrotu karetki
  
  # Informacja diagnostyczna o długości treści
  cat("Długość oryginalnej treści:", nchar(xml_content), "\n")
  
  # Próba wyodrębnienia sekcji <dane>
  pattern <- "<dane>(.*?)</dane>"
  dane_content <- str_extract(xml_content, pattern)
  
  # Sprawdzamy, czy ekstrakcja zadziałała
  if(is.na(dane_content)) {
    cat("Nie udało się wyodrębnić treści <dane>\n")
    
    # Alternatywne podejście - szukanie konkretnej pozycji
    start_pos <- str_locate(xml_content, "<dane>")[1]
    end_pos <- str_locate(xml_content, "</dane>")[1]
    
    if(!is.na(start_pos) && !is.na(end_pos)) {
      dane_content <- substr(xml_content, start_pos, end_pos + 6)
      cat("Wyodrębniono przy użyciu pozycji:", dane_content, "\n")
    }
  } else {
    cat("Poprawnie wyodrębniono treść <dane>\n")
  }
  
  # Jeśli nie udało się znaleźć treści dane, zwracamy NULL
  if(is.na(dane_content)) {
    cat("Nie znaleziono treści <dane>\n")
    return(NULL)
  }
  
  # Usuwamy tagi dane
  dane_content <- gsub("<dane>|</dane>", "", dane_content)
  
  # Tworzymy listę do przechowywania wszystkich znalezionych nazw tagów
  all_tags <- list()
  
  # KROK 1: Znajdź wszystkie tagi otwierające
  opening_tags <- str_extract_all(dane_content, "<[^/][^>]*>")[[1]]
  for(tag in opening_tags) {
    # Wyciągnij nazwę tagu
    tag_name <- str_extract(tag, "(?<=<)[^>\\s]+")
    all_tags[[tag_name]] <- TRUE
  }
  
  # KROK 2: Znajdź wszystkie tagi samozamykające się
  self_closing_tags <- str_extract_all(dane_content, "<[^>]+/>")[[1]]
  for(tag in self_closing_tags) {
    # Wyciągnij nazwę tagu
    tag_name <- str_extract(tag, "(?<=<)[^>\\s/]+")
    all_tags[[tag_name]] <- TRUE
  }
  
  # Tworzymy listę do przechowywania wyników
  search_results <- list()
  
  # Przetwarzamy każdy znany tag
  for(tag_name in names(all_tags)) {
    # Próbujemy wyciągnąć zawartość między tagami otwierającym i zamykającym
    pattern <- paste0("<", tag_name, ">(.*?)</", tag_name, ">")
    content <- str_extract(dane_content, pattern)
    
    if(!is.na(content)) {
      # Wyciągamy tylko zawartość
      content <- gsub(pattern, "\\1", content)
    } else {
      # Sprawdzamy, czy to tag samozamykający się
      self_closing_pattern <- paste0("<", tag_name, "\\s*/>")
      if(str_detect(dane_content, self_closing_pattern)) {
        # Tag samozamykający się, użyj "|" jak żądano
        content <- "|"
      } else {
        # Tag istnieje, ale nie można wyciągnąć zawartości, może być pusty
        content <- ""
      }
    }
    
    # Dodaj do wyników
    cat("Przetwarzanie tagu:", tag_name, "=", content, "\n")
    search_results[[tag_name]] <- content
  }
  
  # Konwersja na ramkę danych
  if(length(search_results) == 0) {
    cat("Brak wyników do przetworzenia\n")
    return(NULL)
  } else {
    search_results_df <- data.frame(t(unlist(search_results)), stringsAsFactors = FALSE)
    print(search_results_df)
    return(search_results_df)
  }
}

# Funkcja łącząca wyszukiwanie i parsowanie w jednym kroku
# Upraszcza korzystanie z API przez połączenie dwóch etapów
search_and_parse <- function(parameter_value, parameter_name = "Nip", user_key = USER_KEY) {
  tryCatch({
    response <- search_entities(parameter_value, parameter_name, user_key)
    results <- parse_search_results(response)
    return(results)
  }, error = function(e) {
    cat("Wystąpił błąd:", e$message, "\n")
    return(NULL)
  })
}

# Przykład użycia:
#regon_results <- search_and_parse("000331501", "Regon")
nip_results <- search_and_parse("6262619005", "Nip")

# Zapisujemy wyniki do pliku z separatorem |
write_delim(nip_results, "dolor.txt", delim="|")#, append = TRUE)


# Funkcja do przetwarzania wielu NIP-ów z pliku i dołączania wyników do istniejącego pliku wyjściowego
process_nip_file <- function(file_path = "E:/API_REGON/dolor2", output_file = "loremipsum.txt", user_key = USER_KEY) {
  # Wczytujemy NIP-y z pliku (zakładając jeden NIP na linię)
  nips <- readLines(file_path)
  
  # Usuwamy puste linie lub białe znaki
  nips <- trimws(nips)
  nips <- nips[nips != ""]
  
  cat("Znaleziono", length(nips), "NIP-ów do przetworzenia\n")
  
  # Inicjalizujemy licznik udanych wyszukiwań
  success_count <- 0
  
  # Przetwarzamy każdy NIP
  for(i in 1:length(nips)) {
    nip <- nips[i]
    cat("Przetwarzanie", i, "z", length(nips), ":", nip, "\n")
    
    # Dodajemy opóźnienie, aby nie przeciążać API (dostosuj w razie potrzeby)
    if(i > 1) Sys.sleep(1)
    
    # Używamy istniejących funkcji do wyszukiwania i pobierania wyników
    response <- search_entities(nip, "Nip", user_key)
    dane_df <- parse_search_results(response)
    
    # Sprawdzamy, czy otrzymaliśmy wyniki
    if(!is.null(dane_df) && nrow(dane_df) > 0) {
      # Zapisujemy do pliku z append = TRUE, używając istniejącego podejścia
      write_delim(dane_df, "NIPY.txt", delim = "|", append = TRUE)
      
      success_count <- success_count + 1
      cat("Pomyślnie przetworzono i zapisano dane dla NIP:", nip, "\n")
    } else {
      cat("Nie znaleziono danych dla NIP:", nip, "\n")
    }
  }
  
  cat("Przetwarzanie zakończone. Pomyślnie przetworzono", success_count, "z", length(nips), "NIP-ów\n")
}

# Przykład użycia:
process_nip_file("dolor2.txt") 
  
# Wylogowujemy dziękuje za uwagę
wyloguj(sid) 

