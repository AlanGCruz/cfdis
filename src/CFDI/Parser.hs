module CFDI.Parser (parseCFDI) where

import Data.Maybe           (fromJust, fromMaybe)
import Data.Time.LocalTime  (LocalTime)
import Data.Time.Parse      (strptime)
import Text.XML.Light.Input (parseXMLDoc)
import Text.XML.Light.Lexer (XmlSource)
import Text.XML.Light.Proc  (filterElementName, filterElementsName, findAttrBy)
import Text.XML.Light.Types (Element(Element), QName(QName))
import CFDI.Types

findAttrValueByName :: String -> Element -> Maybe String
findAttrValueByName attrName =
  findAttrBy (nameEquals attrName)

findChildByName :: String -> Element -> Maybe Element
findChildByName childName =
  filterElementName (nameEquals childName)

findChildrenByName :: String -> Element -> [Element]
findChildrenByName childName =
  filterElementsName (nameEquals childName)

nameEquals :: String -> QName -> Bool
nameEquals s (QName name _ _) =
  s == name

parseAddress :: Element -> Address
parseAddress element = Address
  { country        = requireAttrValueByName "pais" element
  , externalNumber = findAttrValueByName "noExterior" element
  , internalNumber = findAttrValueByName "noInterior" element
  , locality       = findAttrValueByName "localidad" element
  , municipality   = findAttrValueByName "municipio" element
  , reference      = findAttrValueByName "referencia" element
  , suburb         = findAttrValueByName "colonia" element
  , state          = findAttrValueByName "estado" element
  , street         = findAttrValueByName "calle" element
  , zipCode        = findAttrValueByName "codigoPostal" element
  }

parseCFDI :: XmlSource s => s -> Maybe CFDI
parseCFDI xmlSource =
  parseCFDIv3_2 <$> parseXMLDoc xmlSource

parseCFDIv3_2 :: Element -> CFDI
parseCFDIv3_2 root = CFDI
  { accountNumber     = findAttrValueByName "NumCtaPago" root
  , certificate       = requireAttrValueByName "certificado" root
  , certificateNumber = requireAttrValueByName "noCertificado" root
  , currency          = findAttrValueByName "Moneda" root
  , expeditionPlace   = requireAttrValueByName "LugarExpedicion" root
  , internalID        = findAttrValueByName "folio" root
  , issuedAt          = parseDateTime $ requireAttrValueByName "fecha" root
  , issuer            = parseIssuer $ requireChildByName "Emisor" root
  , paymentConditions = findAttrValueByName "condicionesDePago" root
  , paymentMethod     = requireAttrValueByName "metodoDePago" root
  , subTotal          = read $ requireAttrValueByName "subTotal" root
  , signature         = fromMaybe "" $ findAttrValueByName "sello" root
  , total             = read $ requireAttrValueByName "total" root
  , _type             = requireAttrValueByName "tipoDeComprobante" root
  , version           = requireAttrValueByName "version" root
  }

parseDateTime :: String -> LocalTime
parseDateTime =
  fst . fromJust . strptime "%Y-%m-%dT%H:%M:%S"

parseFiscalAddress :: Element -> FiscalAddress
parseFiscalAddress element = FiscalAddress
  { fiscalCountry        = requireAttrValueByName "pais" element
  , fiscalExternalNumber = findAttrValueByName "noExterior" element
  , fiscalInternalNumber = findAttrValueByName "noInterior" element
  , fiscalLocality       = findAttrValueByName "localidad" element
  , fiscalMunicipality   = requireAttrValueByName "municipio" element
  , fiscalReference      = findAttrValueByName "referencia" element
  , fiscalSuburb         = findAttrValueByName "colonia" element
  , fiscalState          = requireAttrValueByName "estado" element
  , fiscalStreet         = requireAttrValueByName "calle" element
  , fiscalZipCode        = requireAttrValueByName "codigoPostal" element
  }

parseIssuer :: Element -> Issuer
parseIssuer element = Issuer
  { fiscalAddress = parseFiscalAddress
                <$> findChildByName "DomicilioFiscal" element
  , name          = findAttrValueByName "nombre" element
  , rfc           = requireAttrValueByName "rfc" element
  }

requireAttrValueByName :: String -> Element -> String
requireAttrValueByName attrName =
  fromJust . findAttrValueByName attrName

requireChildByName :: String -> Element -> Element
requireChildByName childName =
  fromJust . findChildByName childName
