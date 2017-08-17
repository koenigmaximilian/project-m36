import ProjectM36.Client.Simple
import Test.HUnit
import System.Exit
import ProjectM36.Relation
import qualified ProjectM36.Client as C
import System.IO.Temp
import System.FilePath
import ProjectM36.TupleSet
import ProjectM36.Attribute
import ProjectM36.Error
import qualified Data.Vector as V

main :: IO ()           
main = do 
  tcounts <- runTestTT testList
  if errors tcounts + failures tcounts > 0 then exitFailure else exitSuccess
  
testList :: Test
testList = TestList [testSimpleCommitSuccess, testSimpleCommitFailure]

assertEither :: (Show a) => IO (Either a b) -> IO b
assertEither x = do
  res <- x
  case res of
    Left err -> assertFailure (show err) >> undefined
    Right val -> pure val

testSimpleCommitSuccess :: Test
testSimpleCommitSuccess = TestCase $
  withSystemTempDirectory "m36tempdb" $ \tempdir -> do
    let connInfo = InProcessConnectionInfo (MinimalPersistence (tempdir </> "db")) emptyNotificationCallback []
        relExpr = Union (RelationVariable "x" ()) (RelationVariable "y" ())
    
    Right _ <- withDBConnection connInfo $ do
      Right _ <- withTransaction [
                          Assign "x" (ExistingRelation relationTrue),
                          Assign "y" (ExistingRelation relationFalse)
                          ]
      query relExpr
  
  -- re-open with standard API and validate that the relvars are available
    conn <- assertEither $ C.connectProjectM36 connInfo
    
    sess <- assertEither $ C.createSessionAtHead conn "master"
    eRes <- C.executeRelationalExpr sess conn relExpr
    assertEqual "x and y" (Right relationTrue) eRes
    
testSimpleCommitFailure :: Test
testSimpleCommitFailure = TestCase $ do
  let failAttrs = attributesFromList [Attribute "fail" IntAtomType]
  err <- withSystemTempDirectory "m36tempdb" $ \tempdir -> do
    let connInfo = InProcessConnectionInfo (MinimalPersistence (tempdir </> "db")) emptyNotificationCallback []
    withDBConnection connInfo $ do
      Right _ <- withTransaction [Assign "x" (ExistingRelation relationTrue)]
      --cause error
      withTransaction [Assign "x" (MakeStaticRelation failAttrs emptyTupleSet)]
  let expectedErr = Left (RelError (RelVarAssignmentTypeMismatchError V.empty failAttrs))
  assertEqual "dbc error" expectedErr err
  




    
      
  