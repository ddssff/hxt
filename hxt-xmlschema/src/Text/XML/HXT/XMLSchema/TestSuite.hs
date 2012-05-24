{- |
   Module     : Text.XML.HXT.XMLSchema.TestSuite
   Copyright  : Copyright (C) 2012 Thorben Guelck, Uwe Schmidt
   License    : MIT

   Maintainer : Uwe Schmidt (uwe@fh-wedel.de)
   Stability  : experimental
   Portability: portable

   Contains a HUnit testsuite for the hxt-xmlschema validator.
-}

module Text.XML.HXT.XMLSchema.TestSuite
  ( runTestSuite )
where

import Text.XML.HXT.Core

import Text.XML.HXT.XMLSchema.Validation
import Text.XML.HXT.XMLSchema.Loader     ( loadDefinition )

import Test.HUnit                        ( Test (TestList)
                                         , (~:)
                                         , (@?=)
                                         , runTestTT
                                         )

-- ----------------------------------------

type SValResult'   = (Bool, [(String, String)])

toSValResult' :: SValResult -> SValResult'
toSValResult' (t, xs)
    = (t, map (\ (_, x2, x3) -> (x2, x3)) xs)

-- ----------------------------------------

-- | Loads the schema definition and instance documents and invokes validation
validateWithSchema :: SysConfigList -> String -> String -> IO SValResult
validateWithSchema config defUri instUri
  = do
    def <- loadDefinition' config defUri
    case def of
      Nothing -> return (False, [(c_err, "/", "Could not process definition file.")])
      Just d  -> do
                 inst <- loadInstance config instUri
                 case inst of
                   Nothing -> return (False, [(c_err, "/", "Could not process instance file.")])
                   Just i  -> return $ runSVal (SValEnv "" $ createRootDesc d) $ testRoot i

loadDefinition' :: SysConfigList -> String -> IO (Maybe XmlSchema)
loadDefinition' config uri
    = do d <- runX ( constA uri >>> loadDefinition config)
         case d of
           [] -> return Nothing
           _  -> return $ Just $ head d

-- | Loads a schema instance from a given url
loadInstance :: SysConfigList -> String -> IO (Maybe XmlTree)
loadInstance config uri
  = do
    s <- runX ( readDocument ( config ++
                               -- these options can't are mandatory
                               [ withValidate yes        -- validate source
                               , withRemoveWS yes        -- remove redundant whitespace
                               , withPreserveComment no  -- remove comments
                               , withCheckNamespaces yes -- check namespaces
                               ]
                             ) uri
                >>>
                documentStatusOk
                >>>
                getChildren
                >>>
                isElem
              )
    case s of
      [] -> return Nothing
      (t : _) ->  return $ Just t
{-
    if (fst $ head s) == ""
      then return $ Just $ snd $ head s
      else return Nothing
-}

-- ----------------------------------------
{- currently not used

-- | Prints validation results to stdout
printSValResult' :: SValResult' -> IO ()
printSValResult' (status, l)
  = do
    if status
      then putStrLn "\nok.\n"
      else putStrLn "\nerrors occurred:\n"
    mapM_ (\ (a, b) -> putStrLn $ a ++ "\n" ++ b ++ "\n") l
    return ()

-- -}
-- ----------------------------------------

-- | Create a HUnit test for SValResults
mkSValTest :: String -> String -> String-> SValResult' -> Test
mkSValTest label descName instName expectedRes
  = label ~:
    do
    res <- validateWithSchema [ withTrace 0 ]
           ("./tests/" ++ descName ++ ".xsd") $
            "./tests/" ++ instName ++ ".xml"
    (toSValResult' res) @?= expectedRes

-- | A test for SimpleTypes as element values which match
simpleTypesElemsOk :: Test
simpleTypesElemsOk
  = mkSValTest "SimpleTypes inside elems ok" "simpleTypesElems" "simpleTypesElemsOk" $
    (True, [])

-- | A test for SimpleTypes as element values which do not match
simpleTypesElemsErrors :: Test
simpleTypesElemsErrors
  = mkSValTest "SimpleTypes inside elems with errors" "simpleTypesElems" "simpleTypesElemsErrors" $
    (False, [ ( "/root[1]/summerMonth[1]/child::text()"
              , "Parameter restriction: \"minExclusive = 5\" does not hold for value = \"3\".")
            , ( "/root[1]/temperature[1]/child::text()"
              , "Parameter restriction: \"totalDigits = 3\" does not hold for value = \"42\".")
            , ( "/root[1]/password[1]/child::text()"
              , "Parameter restriction: \"maxLength = 10\" does not hold for value = \"a wrong password\".")
            , ( "/root[1]/monthByName[1]/child::text()"
              , "Parameter restriction: \"length = 3\" does not hold for value = \"wrong\".")
            , ( "/root[1]/plz[1]/child::text()"
              , "Parameter restriction: \"pattern = (D )?[0-9]{5}\" does not hold for value = \"42\".")
            , ( "/root[1]/monthList[1]/child::text()"
              , "value does not match list type.")
            , ( "/root[1]/month[1]/child::text()"
              , "value does not match union type.")
            , ( "/root[1]/leapYear[1]/child::text()"
              , "\"perhaps\" is no valid boolean.")
            ])

-- | A test for SimpleTypes as attribute values which match
simpleTypesAttrsOk :: Test
simpleTypesAttrsOk
  = mkSValTest "SimpleTypes inside attrs ok" "simpleTypesAttrs" "simpleTypesAttrsOk" $
    (True, [])

-- | A test for SimpleTypes as attribute values which do not match
simpleTypesAttrsErrors :: Test
simpleTypesAttrsErrors
  = mkSValTest "SimpleTypes inside attrs with errors" "simpleTypesAttrs" "simpleTypesAttrsErrors" $
    (False, [ ( "/root[1]/@summerMonth"
              , "Parameter restriction: \"maxExclusive = 9\" does not hold for value = \"10\".")
            , ( "/root[1]/@temperature"
              , "Parameter restriction: \"fractionDigits = 1\" does not hold for value = \"421\".")
            , ( "/root[1]/@password"
              , "Parameter restriction: \"minLength = 5\" does not hold for value = \"safe\".")
            , ( "/root[1]/@plz"
              , "Parameter restriction: \"pattern = (D )?[0-9]{5}\" does not hold for value = \"42\".")
            , ( "/root[1]/@monthList"
              , "value does not match list type.")
            , ( "/root[1]/@month"
              , "value does not match union type.")
            ])

-- | A test for ComplexTypes which match
complexTypesOk :: Test
complexTypesOk
  = mkSValTest "ComplexTypes ok" "complexTypes" "complexTypesOk" $
    (True, [])

-- | A test for ComplexTypes which do not match
complexTypesErrors :: Test
complexTypesErrors
  = mkSValTest "ComplexTypes with errors" "complexTypes" "complexTypesErrors" $
    (False, [ ( "/root[1]/password[1]/child::text()"
              , "Parameter restriction: \"maxLength = 10\" does not hold for value = \"wrong password\".")
            , ( "/root[1]/login[1]/@username"
              , "required attribute is missing.")
            , ( "/root[1]/login[1]/child::text()"
              , "Parameter restriction: \"minLength = 5\" does not hold for value = \"foo\".")
            , ( "/root[1]/customer[1]/@age"
              , "\"wrong\" is no valid integer.")
            , ( "/root[1]/customer[1]/*"
              , "content does not match content model.\ninput does not match <firstName><lastName>")
            , ( "/root[1]/shoppingList[1]/*"
              , "content does not match content model.\nexpected: <bread>, but got: <butter>1</butter>")
            , ( "/root[1]/computer[1]/*"
              , "content does not match content model.\nexpected: <desktop>|<laptop>, but got: <tablet/>")
            , ( "/root[1]/computerData[1]/*"
              , "content does not match content model.\nexpected: <comment>, but got: <ram>64GB</ram>")
            , ( "/root[1]/computerDataWithGPU[1]/*"
              , "no mixed content allowed here.")
            , ( "/root[1]/computerDataWithGPU[2]/*"
              , "content does not match content model.\ninput does not match <name>(<cpu>)?(<ram>)?(<comment>)*<gpu>")
            , ( "/root[1]/computerDataWithoutComments[1]/*"
              , "content does not match content model.\nexpected: <cpu>, but got: <comment>good display!</comment>")
            ])

-- | A test for redefinitions
redefine :: Test
redefine
  = mkSValTest "Redefine" "redefine" "redefine" $
    (False, [ ( "/root[1]/validCustomer[2]/child::text()"
              , "Parameter restriction: \"maxInclusive = 18\" does not hold for value = \"21\".")
            ])

-- ----------------------------------------

-- | The hxt-xmlschema testsuite
testSuite :: Test
testSuite
  = TestList [ simpleTypesElemsOk
             , simpleTypesElemsErrors
             , simpleTypesAttrsOk
             , simpleTypesAttrsErrors
             , complexTypesOk
             , complexTypesErrors
             , redefine
             ]

-- ----------------------------------------

-- | Run the hxt-xmlschema testsuite
runTestSuite :: IO ()
runTestSuite
  = do
    _ <- runTestTT testSuite
    return ()

-- ----------------------------------------