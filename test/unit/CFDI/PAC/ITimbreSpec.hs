{-# LANGUAGE OverloadedStrings #-}

module CFDI.PAC.ITimbreSpec
  ( spec
  ) where

import CFDI
import CFDI.PAC            (StampError(PacError), getPacStamp, stampLookup)
import CFDI.PAC.ITimbre
import Data.Either         (isLeft, isRight)
import Data.Text           (Text, take, unpack)
import Data.Time.Calendar  (Day(ModifiedJulianDay))
import Data.Time.LocalTime (LocalTime(..), TimeOfDay(..), localDay)
import Data.Time.Calendar  (addDays)
import Data.Time.Clock     (getCurrentTime)
import Data.Time.Format    (defaultTimeLocale, formatTime, parseTimeM)
import Data.Yaml
  ( FromJSON
  , Value(Object)
  , (.:)
  , decodeFile
  , parseJSON
  )
import Prelude      hiding (take)
import System.Directory    (doesFileExist, removeFile)
import System.IO.Temp      (writeSystemTempFile)
import Test.Hspec

data ITimbreCreds = ITimbreCreds Text Text Text Text String

instance FromJSON ITimbreCreds where
  parseJSON (Object v) = ITimbreCreds
    <$> v .: "user"
    <*> v .: "pass"
    <*> v .: "rfc"
    <*> v .: "csdCert"
    <*> v .: "csdPem"

cfdi :: CFDI
cfdi = CFDI
  (Just (CertificateNumber "00001000000403544254"))
  Nothing
  Income
  []
  (Concepts
    [ Concept
        (Amount 1090.52)
        []
        (ProductDescription "COMIDA MEXICANA")
        Nothing
        MU_ACT
        (Just (ProductId "PROD12"))
        (ProductOrService 91111700)
        (Quantity 1)
        (Just (ConceptTaxes
                Nothing
                (Just (ConceptTransferedTaxes
                        [ ConceptTransferedTax
                            (Amount 174.48)
                            (TaxBase 1090.52)
                            Rate
                            (TaxRate 0.16)
                            IVA
                        ]))))
        (Just (ProductUnit "NA"))
        (Amount 1090.52)
    ])
  Nothing
  CUR_MXN
  Nothing
  Nothing
  (Just (Folio "12"))
  (LocalTime
    (ModifiedJulianDay 57953)
    (TimeOfDay 14 27 3))
  (ZipCode 22115)
  (Issuer
    (Just (Name "EMISOR DE PRUEBA"))
    (RFC "LEVM590117199")
    (PeopleWithBusinessActivities))
  (Just (PaymentConditions "CONDICIONES DE PAGO DE PRUEBA"))
  (Just OneTimePayment)
  (Recipient
    (Just GeneralExpenses)
    (Just (Name "RECEPTOR DE PRUEBA"))
    (RFC "XAXX010101000")
    Nothing
    Nothing)
  Nothing
  (Just (Series "ABC"))
  Nothing
  (Amount 1090.52)
  (Just (Taxes 
          Nothing
          (Just (Amount 174.48))
          Nothing
          (Just (TransferedTaxes
                  [ TransferedTax 
                      (Amount 174.48)
                      Rate
                      (TaxRate 0.16)
                      IVA
                  ]))))
  (Amount 1265)
  (Version 3.3)
  (Just Cash)

spec :: Spec
spec = do
  let credsFilePath = "test/yaml/pac-credentials/itimbre.yml"
  credsFileExist <- runIO $ doesFileExist credsFilePath

  if credsFileExist
    then do
      (itimbre, pem, crt) <- runIO $ do
        Just (ITimbreCreds usr pass_ rfc_ crt pem) <- decodeFile credsFilePath
        return (ITimbre usr pass_ rfc_ Testing, pem, crt)

      describe "CFDI.PAC.ITimbre.ITimbre instance of PAC" $ do
        it "implements getPacStamp function" $ do
          currentTimeStr <- formatTime defaultTimeLocale f <$> getCurrentTime
          now <- parseTimeM True defaultTimeLocale f currentTimeStr
          pemFilePath <- writeSystemTempFile "csd.pem" pem
          let cfdi' = cfdi
                { certText = Just crt
                , issuedAt = time
                }
              time = now { localDay = addDays (-1) (localDay now) }
          Right signedCfdi@CFDI{signature = Just sig} <-
            signWith pemFilePath cfdi'
          let cfdiId = take 12 sig
          eitherErrOrStamp <- getPacStamp signedCfdi itimbre cfdiId
          eitherErrOrStamp `shouldSatisfy` isRight
          removeFile pemFilePath

        it "implements stampLookup function" $ do
          -- We need to stamp a CFDI first to test this.
          currentTimeStr <- formatTime defaultTimeLocale f <$> getCurrentTime
          now <- parseTimeM True defaultTimeLocale f currentTimeStr
          pemFilePath <- writeSystemTempFile "csd.pem" pem
          let cfdi' = cfdi
                { certText = Just crt
                , issuedAt = time
                }
              time = now { localDay = addDays (-1) (localDay now) }
          Right signedCfdi@CFDI{signature = Just sig} <-
            signWith pemFilePath cfdi'
          let cfdiId = take 12 sig
          eitherErrOrStamp <- getPacStamp signedCfdi itimbre cfdiId
          eitherErrOrStamp `shouldSatisfy` isRight

          eitherErrOrStamp' <- getPacStamp signedCfdi itimbre cfdiId
          eitherErrOrStamp' `shouldSatisfy` isLeft
          let Left (PacError _ code) = eitherErrOrStamp'
          code `shouldBe` Just "307"

          eitherErrOrStamp'' <- stampLookup itimbre cfdiId
          eitherErrOrStamp'' `shouldSatisfy` isRight
          removeFile pemFilePath
    else
      return ()
  where
    f = "%Y-%m-%d-%H-%M-%S-%Z"
