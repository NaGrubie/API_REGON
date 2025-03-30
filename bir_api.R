###################################################################
# API REGON GUS - DanePełnyRaport; pojedyncze i wielorakie rekordy #
###################################################################
library(stringr)
library(readr)
library(httr2)
library(xml2)

# Dane logowania do API BIR
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

# Funkcja do pobierania pełnego raportu z bazy REGON
get_full_report <- function(regon, report_name = "BIR11OsPrawna", user_key = USER_KEY, sid = NULL) {
  # Tworzenie koperty SOAP
  soap_body <- paste0(
    '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" ',
    'xmlns:ns="http://CIS/BIR/PUBL/2014/07">',
    '<soap:Header xmlns:wsa="http://www.w3.org/2005/08/addressing">',
    '<wsa:To>https://wyszukiwarkaregontest.stat.gov.pl/wsBIR/UslugaBIRzewnPubl.svc</wsa:To>',
    '<wsa:Action>http://CIS/BIR/PUBL/2014/07/IUslugaBIRzewnPubl/DanePobierzPelnyRaport</wsa:Action>',
    '</soap:Header>',
    '<soap:Body>',
    '<ns:DanePobierzPelnyRaport>',
    '<ns:pRegon>', regon, '</ns:pRegon>',
    '<ns:pNazwaRaportu>', report_name, '</ns:pNazwaRaportu>',
    '</ns:DanePobierzPelnyRaport>',
    '</soap:Body>',
    '</soap:Envelope>'
  )
  
  # Tworzenie i wykonanie zapytania
  req <- request("https://wyszukiwarkaregontest.stat.gov.pl/wsBIR/UslugaBIRzewnPubl.svc") %>%
    req_method("POST") %>%
    req_headers(
      "Content-Type" = "application/soap+xml;charset=UTF-8",
      "SOAPAction" = "http://CIS/BIR/PUBL/2014/07/IUslugaBIRzewnPubl/DanePobierzPelnyRaport",
      "User-Key" = user_key
    ) 
  
  # Dodanie identyfikatora sesji, jeśli został podany
  if(!is.null(sid)) {
    req <- req %>% req_headers("sid" = sid)
  }
  
  # Dodanie treści zapytania i wykonanie
  req <- req %>% req_body_raw(soap_body)
  resp <- req_perform(req)
  
  return(resp)
}

# Funkcja do pobierania i wyświetlania wyniku pełnego raportu
get_full_report_result <- function(regon, report_name = "BIR11OsPrawna", user_key = USER_KEY, sid = NULL) {
  # Pobierz pełny raport
  result_report <- get_full_report(regon, report_name, user_key, sid)
  
  # Wyciągnij tekst odpowiedzi
  response_text <- resp_body_string(result_report)
  
  # Wyświetl tekst odpowiedzi
  print(response_text)
  
  # Zwróć wynik do dalszego przetwarzania w razie potrzeby
  return(result_report)
}

# Przykładowe użycie - pobieramy dane dla konkretnego numeru REGON
result_regon <- get_full_report_result("273650781", "BIR11OsPrawna", user_key = USER_KEY, sid = sid)
response_text <- resp_body_string(result_regon)
print(response_text)

# Funkcja do parsowania pełnego raportu
parse_full_report <- function(response_text) {
  # Wyciągnięcie części XML (usunięcie nagłówków koperty SOAP)
  xml_content <- gsub(".*?<DanePobierzPelnyRaportResult>(.*?)</DanePobierzPelnyRaportResult>.*", "\\1", response_text, perl = TRUE)
  
  # Zastępowanie znaków specjalnych
  xml_content <- gsub("&lt;", "<", xml_content)
  xml_content <- gsub("&gt;", ">", xml_content)
  xml_content <- gsub("&#xD;", "", xml_content) # Usunięcie znaków powrotu karetki
  
  library(stringr)
  library(xml2)
  
  # Wyświetlanie oryginalnej zawartości do debugowania
  cat("Długość oryginalnej zawartości:", nchar(xml_content), "\n")
  
  # Próba bardziej solidnego wzorca z flagą s dla wielu linii
  pattern <- "(?s)<dane>(.*?)</dane>"
  dane_content <- str_extract(xml_content, pattern)
  
  # Sprawdzamy czy ekstrakcja się powiodła
  if(is.na(dane_content)) {
    cat("Nie udało się wyciągnąć zawartości <dane>\n")
    
    # Alternatywne podejście - szukanie konkretnej pozycji
    start_pos <- str_locate(xml_content, "<dane>")[1]
    end_pos <- str_locate(xml_content, "</dane>")[1]
    
    if(!is.na(start_pos) && !is.na(end_pos)) {
      dane_content <- substr(xml_content, start_pos, end_pos + 6)
      cat("Wyciągnięto używając pozycji:", dane_content, "\n")
    }
  } else {
    cat("Długość wyciągniętej zawartości:", nchar(dane_content), "\n")
  }
  
  # Parsowanie XML za pomocą xml2
  # Owijamy w try-catch, aby obsłużyć błędy parsowania
  tryCatch({
    # Tworzenie prawidłowego dokumentu XML z elementem głównym
    full_xml <- paste0("<root>", dane_content, "</root>")
    xml_doc <- read_xml(full_xml)
    
    # Pobierz wszystkie elementy pod <dane>
    all_nodes <- xml_find_all(xml_doc, "//dane/*")
    
    cat("Liczba znalezionych elementów:", length(all_nodes), "\n")
    
    # Tworzenie listy do przechowywania wyników
    result_list <- list()
    
    # Przetwarzanie każdego elementu
    for(i in 1:length(all_nodes)) {
      node <- all_nodes[i]
      tag_name <- xml_name(node)
      
      # Pobierz zawartość, która będzie "" dla pustych elementów
      content <- xml_text(node)
      
      # Zastąp pustą zawartość przez "|" zgodnie z wymaganiem
      if(content == "") content <- "|"
      
      # Usuń prefiks "praw_" do wyświetlania, ale zachowaj oryginał do przetwarzania
      clean_tag <- gsub("^praw_", "", tag_name)
      
      cat("Przetwarzanie elementu", i, ":", clean_tag, "=", content, "\n")
      
      # Dodaj do listy wyników z oczyszczoną nazwą tagu
      result_list[[clean_tag]] <- content
    }
    
    # Sprawdź czy mamy jakieś wyniki
    if(length(result_list) == 0) {
      cat("Nie wyciągnięto żadnych elementów\n")
      return(NULL)
    } else {
      # Konwersja do ramki danych
      dane_df <- data.frame(t(unlist(result_list)), stringsAsFactors = FALSE)
      
      # Wyświetl wynik
      print(dane_df)
      return(dane_df)
    }
  }, error = function(e) {
    cat("Błąd parsowania XML:", e$message, "\n")
    
    # Fallback do podejścia z regexem, ale z ulepszonym regexem dla pustych elementów
    dane_content_clean <- gsub("<dane>|</dane>", "", dane_content)
    
    # Ten wzorzec wychwytuje zarówno normalne elementy, jak i samozamykające się tagi
    elements_pattern <- "<([^/>]+)(?:/>|>([^<]*)</\\1>)"
    elements_matches <- str_match_all(dane_content_clean, elements_pattern)[[1]]
    
    cat("Metoda zapasowa - znaleziono elementów:", nrow(elements_matches), "\n")
    
    result_list <- list()
    
    # Przetwarzanie każdego elementu z dopasowań regex
    for(i in 1:nrow(elements_matches)) {
      full_match <- elements_matches[i, 1]
      tag_name <- elements_matches[i, 2]
      content <- elements_matches[i, 3]
      
      # Obsługa samozamykających się tagów (content będzie NA)
      if(is.na(content)) content <- "|"
      
      # Usuń prefiks "praw_"
      clean_tag <- gsub("^praw_", "", tag_name)
      
      cat("Przetwarzanie elementu", i, ":", clean_tag, "=", content, "\n")
      
      # Dodaj do listy wyników
      result_list[[clean_tag]] <- content
    }
    
    # Konwersja do ramki danych
    if(length(result_list) == 0) {
      cat("Nie wyciągnięto żadnych elementów metodą zapasową\n")
      return(NULL)
    } else {
      dane_df <- data.frame(t(unlist(result_list)), stringsAsFactors = FALSE)
      print(dane_df)
      return(dane_df)
    }
  })
}

# Parsujemy raport do ramki danych
dane_df <- parse_full_report(response_text)

# Zapisujemy dane do pliku tekstowego
write_delim(dane_df, "dolor.txt", delim="|")#, append = TRUE)

# Funkcja do przetwarzania wielu numerów REGON z pliku - podmienić ścieżki poniżej na odpowiednie
process_regon_file <- function(regon_file_path = "E:/dane/loremipsum", output_file_path = "dolor.txt", report_name = "BIR11OsPrawna", user_key = USER_KEY, sid = NULL) {
  # Odczytaj numery REGON z pliku
  regons <- readLines(regon_file_path)
  
  # Usuń puste linie lub białe znaki
  regons <- trimws(regons)
  regons <- regons[regons != ""]
  
  cat("Znaleziono", length(regons), "numerów REGON do przetworzenia\n")
  
  # Inicjalizacja licznika udanych wyszukiwań
  success_count <- 0
  
  # Przetwarzanie każdego REGON
  for(i in 1:length(regons)) {
    regon <- regons[i]
    cat("Przetwarzanie", i, "z", length(regons), ":", regon, "\n")
    
    # Dodaj opóźnienie, aby uniknąć przeciążenia API
    if(i > 1) Sys.sleep(1)
    
    # Próba pobrania raportu
    tryCatch({
      # Pobierz pełny raport
      result_regon <- get_full_report(regon, report_name, user_key, sid)
      response_text <- resp_body_string(result_regon)
      
      # Parsuj raport
      dane_df <- parse_full_report(response_text)
      
      # Jeśli otrzymaliśmy wyniki, dopisz je do pliku wyjściowego
      if(!is.null(dane_df) && nrow(dane_df) > 0) {
        # Sprawdź, czy plik istnieje, aby określić, czy trzeba zapisać nagłówki
        file_exists <- file.exists(output_file_path)
        
        # Zapisz do pliku z append = TRUE (po pierwszym zapisie)
        write.table(dane_df, output_file_path, 
                    sep = ",",
                    append = file_exists, 
                    row.names = FALSE, 
                    col.names = !file_exists, 
                    quote = TRUE)
        
        success_count <- success_count + 1
        cat("Pomyślnie przetworzono i zapisano dane dla REGON:", regon, "\n")
      } else {
        cat("Nie znaleziono danych dla REGON:", regon, "\n")
      }
    }, error = function(e) {
      cat("Błąd przetwarzania REGON:", regon, "- Błąd:", e$message, "\n")
    })
  }
  
  cat("Przetwarzanie zakończone. Pomyślnie przetworzono", success_count, "z", length(regons), "numerów REGON\n")
}

# Przetwarzamy plik z numerami REGON
process_regon_file("loremipsum.txt", user_key = USER_KEY, sid = sid)

# Wylogowujemy dziękuje za uwagę
wyloguj(sid)
 
