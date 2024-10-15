using System.Collections;
using System.Collections.Generic;
using UnityEngine;
// using TMPro; // Uncomment if using TextMeshPro

public class Game3Manager : MonoBehaviour
{
    public static Game3Manager Instance;

    //Set via GameManager
    public AudioClip goodMoleAudioClip;
    public AudioClip badMoleAudioClip;

    [Header("Mole Settings")]
    public GameObject goodMolePrefab;
    public GameObject badMolePrefab;
    public Transform[] moleHoles; // Assign hole positions in the inspector

    [Header("UI Elements")]
    // public TMP_Text gameOverText; // Uncomment if using TextMeshPro

    public float spawnInterval = 2.5f;   // Initial time between spawns
    public float moleStayTime = 1.5f;  // Initial time mole stays visible
    public int maxActiveMoles = 1;     // Initial max number of moles active at once
    public float difficultIncrementTime = 10f;
    public bool isGameOver = false;

    // Lists to track holes used in the previous spawn cycle
    public List<int> lastGoodMoleHoles = new List<int>();
    public List<int> lastBadMoleHoles = new List<int>();

    void Awake()
    {
        // Singleton pattern for easy access
        if (Instance == null)
            Instance = this;
        else
            Destroy(gameObject);
    }

    void Start()
    {
        // gameOverText.gameObject.SetActive(false); // Uncomment if using TextMeshPro

    }

    public void GameOver()
    {
        isGameOver = true;
        // gameOverText.gameObject.SetActive(true); // Uncomment if using TextMeshPro
        StopAllCoroutines();

        Debug.Log("Bad mole hit! Game Over!");
        Manager.instance.gameManager.ShowGameOver();
    }

    public IEnumerator SpawnMoles()
    {
        while (!isGameOver)
        {
            List<int> activeHoles = new List<int>();
            List<int> currentGoodMoleHoles = new List<int>();
            List<int> currentBadMoleHoles = new List<int>();

            int molesToSpawn = maxActiveMoles;
            int molesSpawned = 0;

            while (molesSpawned < molesToSpawn)
            {
                // Decide mole type
                bool spawnGoodMole = Random.value < 0.9f;

                // Get list of available holes for the mole type
                List<int> availableHoles = GetAvailableHoles(spawnGoodMole, activeHoles);

                if (availableHoles.Count == 0)
                {
                    // Try swapping mole type
                    spawnGoodMole = !spawnGoodMole;
                    availableHoles = GetAvailableHoles(spawnGoodMole, activeHoles);

                    if (availableHoles.Count == 0)
                    {
                        // No available holes for either mole type
                        break;
                    }
                }

                // Choose a random hole from available holes
                int holeIndex = availableHoles[Random.Range(0, availableHoles.Count)];
                activeHoles.Add(holeIndex);

                // Spawn mole
                SpawnMoleAt(holeIndex, spawnGoodMole);

                // Keep track of holes used for each mole type
                if (spawnGoodMole)
                    currentGoodMoleHoles.Add(holeIndex);
                else
                    currentBadMoleHoles.Add(holeIndex);

                molesSpawned++;
            }

            // Update last mole positions
            lastGoodMoleHoles = new List<int>(currentGoodMoleHoles);
            lastBadMoleHoles = new List<int>(currentBadMoleHoles);

            yield return new WaitForSeconds(spawnInterval);
        }
    }

    private List<int> GetAvailableHoles(bool spawnGoodMole, List<int> activeHoles)
    {
        List<int> availableHoles = new List<int>();

        for (int i = 0; i < moleHoles.Length; i++)
        {
            if (!activeHoles.Contains(i))
            {
                if (spawnGoodMole)
                {
                    if (!lastGoodMoleHoles.Contains(i))
                        availableHoles.Add(i);
                }
                else
                {
                    if (!lastBadMoleHoles.Contains(i))
                        availableHoles.Add(i);
                }
            }
        }

        return availableHoles;
    }

    private void SpawnMoleAt(int index, bool spawnGoodMole)
    {
        if (spawnGoodMole)
        {
            GameObject molePrefab = goodMolePrefab;

            GameObject moleInstance = Instantiate(molePrefab, moleHoles[index].position, Quaternion.identity, moleHoles[index].transform);
            moleInstance.GetComponent<SpriteRenderer>().sprite = Manager.instance.gameManager.playerSprite;
            Game3Mole moleScript = moleInstance.GetComponent<Game3Mole>();
            moleScript.moleAudioClip = goodMoleAudioClip;

            moleScript.isGoodMole = spawnGoodMole;
            moleScript.stayTime = moleStayTime;
        }
        else
        {
            GameObject molePrefab = badMolePrefab;

            GameObject moleInstance = Instantiate(molePrefab, moleHoles[index].position, Quaternion.identity, moleHoles[index].transform);
            Game3Mole moleScript = moleInstance.GetComponent<Game3Mole>();
            moleScript.moleAudioClip = badMoleAudioClip;

            moleScript.isGoodMole = spawnGoodMole;
            moleScript.stayTime = moleStayTime;
        }


    }

    public IEnumerator AdjustDifficulty()
    {
        while (!isGameOver)
        {
            yield return new WaitForSeconds(difficultIncrementTime); // Increase difficulty every 10 seconds

            // Decrease spawn interval to a minimum limit
            if (spawnInterval > 0.5f)
                spawnInterval -= 0.2f;

            // Decrease mole stay time to a minimum limit
            if (moleStayTime > 0.5f)
                moleStayTime -= 0.2f;

            // Increase the number of active moles up to the number of holes
            if (maxActiveMoles < moleHoles.Length)
                maxActiveMoles += 1;
        }
    }
}
