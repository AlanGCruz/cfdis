module CFDI.Types.CFDI where

import CFDI.Types.Amount
import CFDI.Types.CertificateNumber
import CFDI.Types.CfdiType
import CFDI.Types.Concepts
import CFDI.Types.Confirmation
import CFDI.Types.Currency
import CFDI.Types.ExchangeRate
import CFDI.Types.Folio
import CFDI.Types.Issuer
import CFDI.Types.PaymentConditions
import CFDI.Types.PaymentMethod
import CFDI.Types.Recipient
import CFDI.Types.RelatedCfdis
import CFDI.Types.Series
import CFDI.Types.Version
import CFDI.Types.WayToPay
import CFDI.Types.ZipCode
import CFDI.XmlNode
import Data.Text                    (Text)
import Data.Time.LocalTime          (LocalTime)

data CFDI = CFDI
  { certNum       :: Maybe CertificateNumber
  , certText      :: Maybe Text
  , cfdiType      :: CfdiType
  , concepts      :: Concepts
  , confirmation  :: Maybe Confirmation
  , currency      :: Currency
  , discount      :: Maybe Amount
  , exchangeRate  :: Maybe ExchangeRate
  , folio         :: Maybe Folio
  , issuedAt      :: LocalTime
  , issuedIn      :: ZipCode
  , issuer        :: Issuer
  , paymentConds  :: Maybe PaymentConditions
  , paymentMethod :: Maybe PaymentMethod
  , recipient     :: Recipient
  , relatedCfdis  :: Maybe RelatedCfdis
  , series        :: Maybe Series
  , signature     :: Maybe Text
  , subTotal      :: Amount
  , total         :: Amount
  , version       :: Version
  , wayToPay      :: Maybe WayToPay
  } deriving (Eq, Show)

instance XmlNode CFDI where
  parseNode n = CFDI
    <$> parseAttribute "NoCertificado" n
    <*> parseAttribute "Certificado" n
    <*> requireAttribute "TipoDeComprobante" n
    <*> requireChild "Conceptos" n
    <*> parseAttribute "Confirmacion" n
    <*> requireAttribute "Moneda" n
    <*> parseAttribute "Descuento" n
    <*> parseAttribute "TipoCambio" n
    <*> parseAttribute "Folio" n
    <*> requireAttribute "Fecha" n
    <*> requireAttribute "LugarExpedicion" n
    <*> requireChild "Emisor" n
    <*> parseAttribute "CondicionesDePago" n
    <*> parseAttribute "MetodoPago" n
    <*> requireChild "Receptor" n
    <*> parseChild "CfdiRelacionados" n
    <*> parseAttribute "Serie" n
    <*> parseAttribute "Sello" n
    <*> requireAttribute "SubTotal" n
    <*> requireAttribute "Total" n
    <*> requireAttribute "Version" n
    <*> parseAttribute "FormaPago" n
